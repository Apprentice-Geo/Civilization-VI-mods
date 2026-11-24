use anyhow::{ensure, Context, Result};
use std::collections::BTreeSet;
use std::fs::File;
use std::path::Path;

use crate::local::{mark_creation, Release, LOCK_NAME};

pub const PENDING_CREATION: &str = "a previous creation has an unknown outcome. Run list and compare recent items with the request time in .workshop.lock. If you identify the item, set workshop_id and run status. Keep .workshop.lock while the outcome is unknown";
const LEGAL_AGREEMENT: &str =
    "accept the Steam Workshop Legal Agreement on the item's Steam page, then run status";

#[derive(Default)]
pub struct Dependencies {
    pub items: BTreeSet<u64>,
    pub dlc: BTreeSet<u32>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Change {
    RemoveItem(u64),
    AddItem(u64),
    RemoveDlc(u32),
    AddDlc(u32),
}

impl std::fmt::Display for Change {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::RemoveItem(id) => write!(f, "remove required Workshop item {id}"),
            Self::AddItem(id) => write!(f, "add required Workshop item {id}"),
            Self::RemoveDlc(id) => write!(f, "remove required DLC {id}"),
            Self::AddDlc(id) => write!(f, "add required DLC {id}"),
        }
    }
}

impl Dependencies {
    fn changes<'a>(&'a self, release: &'a Release) -> impl Iterator<Item = Change> + 'a {
        let config = &release.config;
        self.items
            .difference(&config.required_items)
            .copied()
            .map(Change::RemoveItem)
            .chain(
                config
                    .required_items
                    .difference(&self.items)
                    .copied()
                    .map(Change::AddItem),
            )
            .chain(
                self.dlc
                    .difference(&config.required_dlc)
                    .copied()
                    .map(Change::RemoveDlc),
            )
            .chain(
                config
                    .required_dlc
                    .difference(&self.dlc)
                    .copied()
                    .map(Change::AddDlc),
            )
    }
}

pub struct Creation {
    pub id: u64,
    pub legal_agreement: bool,
    pub result: Result<()>,
}

pub trait Publisher {
    fn create(&self) -> Result<Creation>;
    fn dependencies(&self, id: u64) -> Result<Dependencies>;
    fn main_update(
        &self,
        release: &Release,
        id: u64,
        staged: &Path,
        note: Option<&str>,
    ) -> Result<bool>;
    fn chinese_update(&self, release: &Release, id: u64) -> Result<bool>;
    fn change_dependency(&self, id: u64, change: Change) -> Result<()>;
}

pub fn publish(
    steam: &impl Publisher,
    dir: &Path,
    lock: &mut File,
    mut release: Release,
    staged: &Path,
    note: Option<&str>,
) -> Result<u64> {
    let mut progress = Progress {
        id: release.config.workshop_id,
        completed: Vec::new(),
    };
    let (id, existing) = if let Some(id) = progress.id {
        (
            id,
            progress.step("read current dependencies", || steam.dependencies(id))?,
        )
    } else {
        ensure!(lock.metadata()?.len() == 0, "{PENDING_CREATION}");
        progress.step("record intent to create a Workshop item", || {
            mark_creation(lock, true)
        })?;
        let create_step = "create Workshop item";
        eprintln!("{} | {create_step}", progress.item());
        let creation = steam
            .create()
            .map_err(|error| progress.failure(create_step, error))?;
        if creation.id == 0 {
            // A successful callback without an ID is ambiguous. Keep the marker in that case.
            if let Err(error) = creation.result {
                progress.step(&format!("clear {LOCK_NAME}"), || mark_creation(lock, false))?;
                return Err(progress.failure(create_step, error));
            }
            return Err(progress.failure(
                create_step,
                anyhow::anyhow!("Steam omitted the ID; outcome unknown"),
            ));
        }

        let id = creation.id;
        progress.id = Some(id);
        if creation.result.is_ok() {
            progress.completed.push(create_step.to_owned());
        }
        eprintln!("Steam assigned Workshop item {id}");
        release.config.workshop_id = Some(id);
        progress.step("save Workshop ID", || release.config.save(dir, true))?;
        progress.step(&format!("clear {LOCK_NAME}"), || mark_creation(lock, false))?;
        creation
            .result
            .map_err(|error| progress.failure(create_step, error))?;
        if creation.legal_agreement {
            return Err(
                progress.failure("Workshop legal agreement", anyhow::anyhow!(LEGAL_AGREEMENT))
            );
        }
        // A newly allocated item has no prior dependencies.
        (id, Dependencies::default())
    };

    let legal_agreement = progress.step("submit content, settings, and English text", || {
        steam.main_update(&release, id, staged, note)
    })?;
    if legal_agreement {
        return Err(progress.failure(
            "Workshop legal agreement after English submission",
            anyhow::anyhow!(LEGAL_AGREEMENT),
        ));
    }
    let legal_agreement = progress.step("submit Simplified Chinese text", || {
        steam.chinese_update(&release, id)
    })?;
    if legal_agreement {
        return Err(progress.failure(
            "Workshop legal agreement after Chinese submission",
            anyhow::anyhow!(LEGAL_AGREEMENT),
        ));
    }
    for change in existing.changes(&release) {
        progress.step(&change.to_string(), || steam.change_dependency(id, change))?;
    }
    Ok(id)
}

struct Progress {
    id: Option<u64>,
    completed: Vec<String>,
}

impl Progress {
    fn step<T>(&mut self, step: &str, perform: impl FnOnce() -> Result<T>) -> Result<T> {
        eprintln!("{} | {step}", self.item());
        let result = perform().map_err(|error| self.failure(step, error))?;
        self.completed.push(step.to_owned());
        Ok(result)
    }

    fn item(&self) -> String {
        self.id.map_or_else(
            || "Workshop ID not assigned".to_owned(),
            |id| format!("Workshop item {id}"),
        )
    }

    fn failure(&self, step: &str, cause: anyhow::Error) -> anyhow::Error {
        let completed = if self.completed.is_empty() {
            "none".to_owned()
        } else {
            self.completed.join(", ")
        };
        let recovery = if self.id.is_some() {
            "Run status to check Steam before manually publishing again. Omit --note if the main submission already posted it. If saving the ID failed, set workshop_id to the ID above first."
        } else {
            "If the creation outcome is unknown, run list and compare recent items with the request time in .workshop.lock."
        };
        cause.context(format!(
            "{}\nFailed step: {step}\nCompleted steps: {completed}\n{recovery}",
            self.item()
        ))
    }
}

pub fn check_pending_creation(dir: &Path, id: Option<u64>) -> Result<()> {
    if id.is_none() {
        match std::fs::metadata(dir.join(LOCK_NAME)) {
            Ok(marker) => ensure!(marker.len() == 0, "{PENDING_CREATION}"),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => (),
            Err(error) => return Err(error).context("read Workshop creation state"),
        }
    }
    Ok(())
}
