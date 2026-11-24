use anyhow::{bail, Result};
use std::cell::{Cell, RefCell};
use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use tempfile::TempDir;

use crate::local::{lock, Config, ItemType, Package, Release, LOCK_NAME};
use crate::publish::{check_pending_creation, publish, Change, Creation, Dependencies, Publisher};

const ID: u64 = 1_234_567_890;

fn repo() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()
        .unwrap()
}

fn workshop_fixture() -> TempDir {
    let fixture = tempfile::tempdir().unwrap();
    let source = repo().join("BarbarianWard");
    for file in ["BarbarianWard.modinfo", "BarbarianWard.sql"] {
        fs::copy(source.join(file), fixture.path().join(file)).unwrap();
    }
    fs::copy(
        repo().join("covers/BarbarianWard.png"),
        fixture.path().join("cover.png"),
    )
    .unwrap();
    fs::write(
        fixture.path().join("workshop.json"),
        r#"{
      "cover": "cover.png",
      "visibility": "private",
      "tags": ["Gameplay", "Base Game"],
      "english": {
        "title": "Barbarian Ward",
        "description": "Human combat units gain a 99 advantage when combating barbarian units."
      },
      "schinese": {
        "title": "蛮族退散",
        "description": "人类战斗单位与蛮族单位战斗时获得99战斗力增益。"
      },
      "required_items": [],
      "required_dlc": []
    }"#,
    )
    .unwrap();
    fixture
}

#[test]
fn packages_only_the_repository_manifests_and_their_listed_files() {
    let mut mod_count = 0;
    for entry in fs::read_dir(repo()).unwrap() {
        let dir = entry.unwrap().path();
        if !dir.is_dir()
            || !dir
                .join(dir.file_name().unwrap())
                .with_extension("modinfo")
                .is_file()
        {
            continue;
        }
        mod_count += 1;
        let package = Package::read(&dir).unwrap();
        let staged = package.stage(&dir).unwrap();
        for path in &package.files {
            assert_eq!(
                fs::read(dir.join(path)).unwrap(),
                fs::read(staged.path().join(path)).unwrap()
            );
        }
        assert_eq!(file_count(staged.path()), package.files.len());
        if dir.ends_with("PeoplesWar") {
            assert!(staged
                .path()
                .join("Gameplay/PeoplesWar_Gameplay.lua")
                .is_file());
            assert!(!staged.path().join("Tools").exists());
        }
    }
    assert!(mod_count >= 12);
}

fn file_count(dir: &Path) -> usize {
    fs::read_dir(dir)
        .unwrap()
        .map(|entry| {
            let entry = entry.unwrap();
            if entry.file_type().unwrap().is_dir() {
                file_count(&entry.path())
            } else {
                1
            }
        })
        .sum()
}

#[test]
fn plan_checks_files_tags_and_utf8_byte_lengths() {
    let fixture = workshop_fixture();
    let dir = fixture.path().canonicalize().unwrap();
    let mut config = Config::read(&dir).unwrap();
    assert_eq!(config.steam_tags(), ["Mod", "Gameplay", "Base Game"]);
    config.item_type = ItemType::Map;
    config.schinese.title = "文".repeat(42);
    config.save(&dir, true).unwrap();
    let release = Release::read(&dir, None).unwrap();
    assert_eq!(
        release.config.steam_tags(),
        ["Map", "Gameplay", "Base Game"]
    );

    config.schinese.title.push('文');
    config.save(&dir, true).unwrap();
    assert!(Release::read(&dir, None)
        .err()
        .unwrap()
        .to_string()
        .contains("129 UTF-8 bytes"));

    config.schinese.title = "蛮族退散".into();
    config.save(&dir, true).unwrap();
    fs::remove_file(dir.join("BarbarianWard.sql")).unwrap();
    assert!(Release::read(&dir, None)
        .err()
        .unwrap()
        .to_string()
        .contains("BarbarianWard.sql"));
}

#[derive(Default)]
struct FakeSteam {
    failure: Cell<Option<&'static str>>,
    creates: Cell<usize>,
    notes: RefCell<Vec<Option<String>>>,
    changes: RefCell<Vec<Change>>,
    current_items: RefCell<BTreeSet<u64>>,
    current_dlc: RefCell<BTreeSet<u32>>,
}

impl FakeSteam {
    fn fail_at(&self, operation: &str) -> Result<()> {
        if self.failure.get() == Some(operation) {
            bail!("simulated {operation} timeout; outcome unknown");
        }
        Ok(())
    }
}

impl Publisher for FakeSteam {
    fn create(&self) -> Result<Creation> {
        self.creates.set(self.creates.get() + 1);
        self.fail_at("create")?;
        Ok(Creation {
            id: ID,
            legal_agreement: false,
            result: Ok(()),
        })
    }

    fn dependencies(&self, id: u64) -> Result<Dependencies> {
        assert_eq!(id, ID);
        self.fail_at("read dependencies")?;
        Ok(Dependencies {
            items: self.current_items.borrow().clone(),
            dlc: self.current_dlc.borrow().clone(),
        })
    }

    fn main_update(&self, _: &Release, id: u64, _: &Path, note: Option<&str>) -> Result<bool> {
        assert_eq!(id, ID);
        self.notes.borrow_mut().push(note.map(str::to_owned));
        self.fail_at("main")?;
        Ok(false)
    }

    fn chinese_update(&self, _: &Release, id: u64) -> Result<bool> {
        assert_eq!(id, ID);
        self.fail_at("Chinese")?;
        Ok(false)
    }

    fn change_dependency(&self, id: u64, change: Change) -> Result<()> {
        assert_eq!(id, ID);
        if change == Change::AddDlc(30) {
            self.fail_at("add DLC")?;
        }
        self.changes.borrow_mut().push(change);
        match change {
            Change::RemoveItem(item) => assert!(self.current_items.borrow_mut().remove(&item)),
            Change::AddItem(item) => assert!(self.current_items.borrow_mut().insert(item)),
            Change::RemoveDlc(app) => assert!(self.current_dlc.borrow_mut().remove(&app)),
            Change::AddDlc(app) => assert!(self.current_dlc.borrow_mut().insert(app)),
        }
        Ok(())
    }
}

fn publish_fixture(steam: &FakeSteam, dir: &Path, note: Option<&str>) -> Result<u64> {
    let mut guard = lock(dir)?;
    let release = Release::read(dir, note)?;
    let staged = release.package.stage(dir)?;
    publish(steam, dir, &mut guard, release, staged.path(), note)
}

#[test]
fn preserves_id_and_reports_the_failed_step_after_creation() {
    for (failure, step) in [
        ("main", "submit content, settings, and English text"),
        ("Chinese", "submit Simplified Chinese text"),
        ("add DLC", "add required DLC 30"),
    ] {
        let fixture = workshop_fixture();
        let dir = fixture.path().canonicalize().unwrap();
        let mut config = Config::read(&dir).unwrap();
        config.required_items.insert(10);
        config.required_dlc.insert(30);
        config.save(&dir, true).unwrap();
        let steam = FakeSteam::default();
        steam.failure.set(Some(failure));
        let error = publish_fixture(&steam, &dir, Some("release note")).unwrap_err();
        let message = format!("{error:#}");
        assert!(message.contains(&format!("Failed step: {step}")));
        assert!(message.contains("Completed steps:"));
        assert!(message.contains("outcome unknown"));
        assert!(message.contains("Run status"));
        let id = Config::read(&dir).unwrap().workshop_id.unwrap();
        assert_eq!(id, ID);
        steam.dependencies(id).unwrap();
        steam.failure.set(None);
        assert_eq!(publish_fixture(&steam, &dir, None).unwrap(), id);
        assert_eq!(steam.creates.get(), 1);
        assert_eq!(*steam.notes.borrow(), [Some("release note".into()), None]);
        assert_eq!(
            *steam.changes.borrow(),
            [Change::AddItem(10), Change::AddDlc(30)]
        );
    }
}

#[test]
fn syncs_both_kinds_of_dependency_and_aborts_on_query_failure() {
    let fixture = workshop_fixture();
    let dir = fixture.path().canonicalize().unwrap();
    let mut config = Config::read(&dir).unwrap();
    config.workshop_id = Some(ID);
    config.required_items.extend([10, 20]);
    config.required_dlc.insert(30);
    config.save(&dir, true).unwrap();
    let steam = FakeSteam::default();
    steam.current_items.borrow_mut().extend([5, 10]);
    steam.current_dlc.borrow_mut().insert(90);
    steam.failure.set(Some("read dependencies"));
    assert!(publish_fixture(&steam, &dir, None).is_err());
    assert!(steam.notes.borrow().is_empty());
    assert!(steam.changes.borrow().is_empty());
    steam.failure.set(None);
    publish_fixture(&steam, &dir, None).unwrap();
    assert_eq!(
        *steam.changes.borrow(),
        [
            Change::RemoveItem(5),
            Change::AddItem(20),
            Change::RemoveDlc(90),
            Change::AddDlc(30)
        ]
    );

    config.required_items.clear();
    config.required_dlc.clear();
    config.save(&dir, true).unwrap();
    publish_fixture(&steam, &dir, None).unwrap();
    assert!(steam.current_items.borrow().is_empty());
    assert!(steam.current_dlc.borrow().is_empty());
}

#[test]
fn unknown_creation_outcome_blocks_a_second_create() {
    let fixture = workshop_fixture();
    let dir = fixture.path().canonicalize().unwrap();
    let steam = FakeSteam::default();
    steam.failure.set(Some("create"));
    let error = publish_fixture(&steam, &dir, None).unwrap_err();
    let message = format!("{error:#}");
    assert!(message.contains("outcome unknown"));
    assert!(message.contains("run list"));
    let marker = fs::read_to_string(dir.join(LOCK_NAME)).unwrap();
    assert!(marker.starts_with("Steam item creation requested at "));
    assert!(marker.trim_end().ends_with('Z'));
    assert!(check_pending_creation(&dir, None).is_err());
    steam.failure.set(None);
    assert!(publish_fixture(&steam, &dir, None).is_err());
    assert_eq!(steam.creates.get(), 1);
}
