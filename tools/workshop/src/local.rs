use anyhow::{ensure, Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fs::{self, File, OpenOptions};
use std::io::{Seek, Write};
use std::path::{Path, PathBuf};
use steamworks_sys as sys;
use tempfile::{NamedTempFile, TempDir};
use time::{format_description::well_known::Rfc3339, OffsetDateTime};

pub const CONFIG_NAME: &str = "workshop.json";
pub const LOCK_NAME: &str = ".workshop.lock";

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub workshop_id: Option<u64>,
    pub cover: Option<PathBuf>,
    pub visibility: Visibility,
    #[serde(rename = "type", default)]
    pub item_type: ItemType,
    pub tags: Vec<String>,
    pub english: LocalizedText,
    pub schinese: LocalizedText,
    pub required_items: BTreeSet<u64>,
    pub required_dlc: BTreeSet<u32>,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Visibility {
    Public,
    FriendsOnly,
    Private,
    Unlisted,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, PartialEq, Serialize)]
pub enum ItemType {
    #[default]
    Mod,
    Map,
}

impl ItemType {
    pub fn tag(self) -> &'static str {
        match self {
            Self::Mod => "Mod",
            Self::Map => "Map",
        }
    }

    pub fn from_tag(tag: &str) -> Option<Self> {
        [Self::Mod, Self::Map]
            .into_iter()
            .find(|item_type| item_type.tag().eq_ignore_ascii_case(tag))
    }
}

#[derive(Debug, Deserialize, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct LocalizedText {
    pub title: String,
    pub description: String,
}

impl Config {
    pub fn read(dir: &Path) -> Result<Self> {
        let path = dir.join(CONFIG_NAME);
        let bytes = fs::read(&path).with_context(|| format!("read {}", path.display()))?;
        let config: Self =
            serde_json::from_slice(&bytes).with_context(|| format!("parse {}", path.display()))?;
        ensure!(config.workshop_id != Some(0), "workshop_id must be nonzero");
        Ok(config)
    }

    pub fn save(&self, dir: &Path, replace: bool) -> Result<()> {
        let path = dir.join(CONFIG_NAME);
        (|| -> Result<()> {
            let mut temp = NamedTempFile::new_in(dir)?;
            serde_json::to_writer_pretty(temp.as_file_mut(), self)?;
            writeln!(temp)?;
            temp.as_file().sync_all()?;
            if replace {
                temp.persist(&path)?;
            } else {
                temp.persist_noclobber(&path)?;
            }
            Ok(())
        })()
        .with_context(|| format!("save {}", path.display()))
    }

    pub fn steam_tags(&self) -> Vec<&str> {
        std::iter::once(self.item_type.tag())
            .chain(self.tags.iter().map(String::as_str))
            .collect()
    }

    fn validate(&self, note: Option<&str>) -> Result<()> {
        for (language, copy) in [("english", &self.english), ("schinese", &self.schinese)] {
            ensure!(!copy.title.trim().is_empty(), "{language}.title is empty");
            validate_text(
                &format!("{language}.title"),
                &copy.title,
                sys::k_cchPublishedDocumentTitleMax as usize - 1,
            )?;
            validate_text(
                &format!("{language}.description"),
                &copy.description,
                sys::k_cchPublishedDocumentDescriptionMax as usize - 1,
            )?;
        }
        if let Some(note) = note {
            validate_text(
                "update note",
                note,
                sys::k_cchPublishedDocumentChangeDescriptionMax as usize - 1,
            )?;
        }
        let mut seen = BTreeSet::new();
        for tag in &self.tags {
            validate_text("tag", tag, 255)?;
            ensure!(
                !tag.is_empty()
                    && tag.trim() == tag
                    && !tag.contains(',')
                    && !tag.chars().any(char::is_control),
                "invalid classification tag {tag:?}"
            );
            ensure!(
                ItemType::from_tag(tag).is_none(),
                "put {tag:?} in type, not tags"
            );
            ensure!(seen.insert(tag.to_lowercase()), "duplicate tag {tag:?}");
        }
        ensure!(
            !self.required_items.contains(&0),
            "required_items contains ID 0"
        );
        ensure!(
            !self.required_dlc.contains(&0),
            "required_dlc contains App ID 0"
        );
        if let Some(id) = self.workshop_id {
            ensure!(
                !self.required_items.contains(&id),
                "item {id} cannot require itself"
            );
        }
        Ok(())
    }
}

fn validate_text(field: &str, value: &str, max_bytes: usize) -> Result<()> {
    ensure!(!value.contains('\0'), "{field} contains a NUL byte");
    ensure!(
        value.len() <= max_bytes,
        "{field} is {} UTF-8 bytes; Steam allows {max_bytes}",
        value.len()
    );
    Ok(())
}

pub struct Package {
    pub mod_id: String,
    pub mod_version: String,
    pub files: Vec<PathBuf>,
    manifest_xml: String,
}

impl Package {
    pub fn read(dir: &Path) -> Result<Self> {
        let manifests = fs::read_dir(dir)?
            .map(|entry| entry.map(|entry| PathBuf::from(entry.file_name())))
            .collect::<std::io::Result<Vec<_>>>()?
            .into_iter()
            .filter(|path| {
                path.extension()
                    .is_some_and(|ext| ext.eq_ignore_ascii_case("modinfo"))
            })
            .collect::<Vec<_>>();
        let [manifest] = manifests.as_slice() else {
            anyhow::bail!("expected exactly one .modinfo in {}", dir.display());
        };
        let xml = fs::read_to_string(package_file(dir, manifest)?)
            .with_context(|| format!("read {} as UTF-8", manifest.display()))?;
        let document = roxmltree::Document::parse(&xml)
            .with_context(|| format!("parse {}", manifest.display()))?;
        let root = document.root_element();
        ensure!(root.has_tag_name("Mod"), "expected a <Mod> root");
        let attribute = |name| -> Result<String> {
            let value = root
                .attribute(name)
                .filter(|value| !value.trim().is_empty())
                .with_context(|| format!("missing .modinfo {name} attribute"))?;
            validate_text(name, value, 255)?;
            Ok(value.to_owned())
        };

        let mut lists = root.children().filter(|node| node.has_tag_name("Files"));
        let list = lists
            .next()
            .context("missing top-level <Files> in .modinfo")?;
        ensure!(lists.next().is_none(), "multiple top-level <Files> lists");
        let mut files = vec![manifest.clone()];
        let mut seen = BTreeSet::new();
        seen.insert(manifest.to_string_lossy().to_lowercase());
        for file in list.children().filter(roxmltree::Node::is_element) {
            ensure!(file.has_tag_name("File"), "expected <File> under <Files>");
            let text = file.text().unwrap_or_default().trim().replace('\\', "/");
            ensure!(
                !text.contains(':') && text.split('/').all(|part| !matches!(part, "" | "." | "..")),
                "invalid .modinfo package path {text:?}"
            );
            let path: PathBuf = text.split('/').collect();
            ensure!(
                seen.insert(text.to_lowercase()),
                "duplicate package path {text:?}"
            );
            package_file(dir, &path)?;
            files.push(path);
        }
        Ok(Self {
            mod_id: attribute("id")?,
            mod_version: attribute("version")?,
            files,
            manifest_xml: xml,
        })
    }

    pub fn stage(&self, dir: &Path) -> Result<TempDir> {
        let staged = tempfile::Builder::new()
            .prefix("civ6-workshop-")
            .tempdir()?;
        fs::write(staged.path().join(&self.files[0]), &self.manifest_xml)?;
        for file in &self.files[1..] {
            let destination = staged.path().join(file);
            fs::create_dir_all(
                destination
                    .parent()
                    .expect("joined staging path has parent"),
            )?;
            fs::copy(package_file(dir, file)?, &destination)
                .with_context(|| format!("stage {}", file.display()))?;
        }
        Ok(staged)
    }
}

fn package_file(dir: &Path, file: &Path) -> Result<PathBuf> {
    let input = dir.join(file);
    let resolved = fs::canonicalize(&input)
        .with_context(|| format!("resolve package file {}", input.display()))?;
    ensure!(
        resolved.starts_with(dir) && resolved.is_file(),
        "package file {} must be a regular file inside the mod directory",
        input.display()
    );
    Ok(resolved)
}

pub struct Release {
    pub config: Config,
    pub package: Package,
    pub cover: PathBuf,
}

impl Release {
    pub fn read(dir: &Path, note: Option<&str>) -> Result<Self> {
        let config = Config::read(dir)?;
        config.validate(note)?;
        let package = Package::read(dir)?;
        let cover = config
            .cover
            .as_ref()
            .context("set cover in workshop.json")?;
        let cover = fs::canonicalize(dir.join(cover))
            .with_context(|| format!("resolve cover {}", cover.display()))?;
        ensure!(
            cover.is_file(),
            "cover must be a regular file: {}",
            cover.display()
        );
        Ok(Self {
            config,
            package,
            cover,
        })
    }
}

pub fn lock(dir: &Path) -> Result<File> {
    let path = dir.join(LOCK_NAME);
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(&path)
        .with_context(|| format!("open {}", path.display()))?;
    file.try_lock()
        .with_context(|| format!("lock {}; another release may be running", path.display()))?;
    Ok(file)
}

pub fn mark_creation(file: &mut File, pending: bool) -> Result<()> {
    file.set_len(0)?;
    if pending {
        file.rewind()?;
        let requested_at = OffsetDateTime::now_utc().format(&Rfc3339)?;
        writeln!(file, "Steam item creation requested at {requested_at}")?;
    }
    file.sync_all()?;
    Ok(())
}
