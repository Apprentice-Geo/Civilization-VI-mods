mod local;
mod publish;
mod steam;
#[cfg(test)]
mod tests;

use anyhow::{ensure, Context, Result};
use clap::{Parser, Subcommand};
use serde_json::{json, Value};
use std::fs;
use std::num::NonZeroU32;
use std::path::{Path, PathBuf};

use local::{Config, ItemType, Release, CONFIG_NAME};
use steam::{item_url, tag_values, OnlineItem, Steam, MOD_ID_TAG, MOD_VERSION_TAG};

#[derive(Parser)]
#[command(
    version,
    about = "Publish Civilization VI mods with the signed-in Steam client"
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// List the signed-in account's Civilization VI Workshop items, newest first.
    List {
        /// Maximum number of items to return.
        #[arg(long, default_value = "20")]
        limit: NonZeroU32,
    },
    /// Save Workshop fields from an existing Civilization VI item to workshop.json.
    Import { mod_dir: PathBuf, workshop_id: u64 },
    /// Validate the release and show exactly what would be submitted, offline.
    Plan { mod_dir: PathBuf },
    /// Read the current Steam fields for the item bound in workshop.json.
    Status { mod_dir: PathBuf },
    /// Publish the configured release or update its bound Workshop item.
    Publish {
        mod_dir: PathBuf,
        /// Send this change note with the English submission.
        #[arg(long)]
        note: Option<String>,
    },
}

fn main() -> std::process::ExitCode {
    match run(Cli::parse().command) {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("Error: {error:#}");
            std::process::ExitCode::FAILURE
        }
    }
}

fn run(command: Command) -> Result<()> {
    match command {
        Command::List { limit } => {
            let items = Steam::connect()?.list_items(limit.get())?;
            print_json(&json!(items))
        }
        Command::Import {
            mod_dir,
            workshop_id,
        } => import(&directory(&mod_dir)?, workshop_id),
        Command::Plan { mod_dir } => {
            let dir = directory(&mod_dir)?;
            let release = Release::read(&dir, None)?;
            publish::check_pending_creation(&dir, release.config.workshop_id)?;
            print_json(&json!({
                "operation": if release.config.workshop_id.is_some() { "update" } else { "create" },
                "workshop_url": release.config.workshop_id.map(item_url),
                "mod_id": release.package.mod_id,
                "mod_version": release.package.mod_version,
                "files": release.package.files.iter().map(|path| path.to_string_lossy().replace('\\', "/")).collect::<Vec<_>>(),
                "steam_tags": release.config.steam_tags(),
                "config": release.config,
            }))
        }
        Command::Status { mod_dir } => {
            let dir = directory(&mod_dir)?;
            let id = Config::read(&dir)?.workshop_id;
            publish::check_pending_creation(&dir, id)?;
            let id = id.context("workshop.json has no workshop_id")?;
            let online = Steam::connect()?
                .read_item(id)
                .with_context(|| format!("read Workshop item {id}"))?;
            warn_language_fallback(&online);
            let (types, tags) = split_tags(&online.tags);
            let label = |name: &str| {
                let values = tag_values(&online.metadata, name);
                if values.len() == 1 {
                    json!(values.first())
                } else if values.is_empty() {
                    Value::Null
                } else {
                    json!(values)
                }
            };
            let item_type = match types.as_slice() {
                [] => Value::Null,
                [value] => json!(value),
                values => json!(values),
            };
            print_json(&json!({
                "workshop_id": id,
                "workshop_url": item_url(id),
                "english": online.english,
                "schinese": online.schinese,
                "visibility": online.visibility,
                "type": item_type,
                "tags": tags,
                "required_items": online.dependencies.items,
                "required_dlc": online.dependencies.dlc,
                "cover_url": online.cover_url,
                "mod_id": label(MOD_ID_TAG),
                "mod_version": label(MOD_VERSION_TAG),
            }))
        }
        Command::Publish { mod_dir, note } => {
            let dir = directory(&mod_dir)?;
            let mut lock = local::lock(&dir)?;
            let release = Release::read(&dir, note.as_deref())?;
            publish::check_pending_creation(&dir, release.config.workshop_id)?;
            let staged = release
                .package
                .stage(&dir)
                .context("stage content for publishing")?;
            let steam = Steam::connect()?;
            let id = publish::publish(
                &steam,
                &dir,
                &mut lock,
                release,
                staged.path(),
                note.as_deref(),
            )?;
            print_json(&json!({"workshop_id": id, "workshop_url": item_url(id)}))
        }
    }
}

fn import(dir: &Path, id: u64) -> Result<()> {
    ensure!(id != 0, "Workshop ID must be nonzero");
    let _lock = local::lock(dir)?;
    let config_path = dir.join(CONFIG_NAME);
    match fs::symlink_metadata(&config_path) {
        Ok(_) => anyhow::bail!("{} already exists", config_path.display()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => (),
        Err(error) => return Err(error).context("check workshop.json"),
    }
    let online = Steam::connect()?
        .read_item(id)
        .with_context(|| format!("read Workshop item {id}"))?;
    warn_language_fallback(&online);
    let (types, tags) = split_tags(&online.tags);
    let item_type = match types.as_slice() {
        [] => {
            eprintln!(
                "Steam returned no Type tag; verify the imported default Mod before publishing."
            );
            ItemType::default()
        }
        [item_type] => *item_type,
        _ => anyhow::bail!("Steam returned both Mod and Map Type tags for item {id}"),
    };
    let basename = dir.file_name().context("mod directory has no name")?;
    let mut cover_name = basename.to_os_string();
    cover_name.push(".png");
    let cover = Path::new("../covers").join(cover_name);
    let cover = dir.join(&cover).is_file().then_some(cover);
    if cover.is_none() {
        eprintln!("No repository cover found. Set cover in workshop.json before publishing.");
    }
    let config = Config {
        workshop_id: Some(id),
        cover,
        visibility: online.visibility,
        item_type,
        tags,
        english: online.english,
        schinese: online.schinese,
        required_items: online.dependencies.items,
        required_dlc: online.dependencies.dlc,
    };
    config.save(dir, false)?;
    print_json(&json!({
        "workshop_id": id,
        "workshop_url": item_url(id),
        "config_path": dunce::simplified(&config_path),
        "cover_url": online.cover_url,
    }))
}

fn split_tags(tags: &[String]) -> (Vec<ItemType>, Vec<String>) {
    let mut types = Vec::new();
    let mut classification = Vec::new();
    for tag in tags {
        if let Some(item_type) = ItemType::from_tag(tag) {
            if !types.contains(&item_type) {
                types.push(item_type);
            }
        } else {
            classification.push(tag.clone());
        }
    }
    (types, classification)
}

fn warn_language_fallback(online: &OnlineItem) {
    if online.english == online.schinese {
        eprintln!("Steam returned identical English and Simplified Chinese text. Check whether Steam fell back to the default language.");
    }
}

fn directory(path: &Path) -> Result<PathBuf> {
    let resolved = fs::canonicalize(path)
        .with_context(|| format!("resolve mod directory {}", path.display()))?;
    ensure!(resolved.is_dir(), "{} is not a directory", path.display());
    Ok(resolved)
}

fn print_json(value: &Value) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}
