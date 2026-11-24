use anyhow::{ensure, Context, Result};
use serde::Serialize;
use std::collections::BTreeSet;
use std::ffi::{c_char, CStr, CString};
use std::mem::{size_of, MaybeUninit};
use std::path::Path;
use std::ptr;
use std::thread;
use std::time::{Duration, Instant};
use steamworks_sys as sys;
use sys::{
    EItemUpdateStatus as UploadStatus, ERemoteStoragePublishedFileVisibility as RawVisibility,
    EResult,
};
use time::{format_description::well_known::Rfc3339, OffsetDateTime};

use crate::local::{LocalizedText, Release, Visibility};
use crate::publish::{Change, Creation, Dependencies, Publisher};

const TOOL_APP_ID: u32 = 404350;
const GAME_APP_ID: u32 = 289070;
const QUERY_TIMEOUT: Duration = Duration::from_secs(30);
const UPLOAD_TIMEOUT: Duration = Duration::from_secs(600);
const UPLOAD_REPORT_INTERVAL: Duration = Duration::from_secs(5);
pub const MOD_ID_TAG: &str = "ModId";
pub const MOD_VERSION_TAG: &str = "ModVersion";

pub struct Steam {
    ugc: *mut sys::ISteamUGC,
    pipe: sys::HSteamPipe,
}

impl Steam {
    pub fn connect() -> Result<Self> {
        // The CLI initializes Steam once on the main thread and keeps it alive through all calls.
        std::env::set_var("SteamAppId", TOOL_APP_ID.to_string());
        std::env::set_var("SteamGameId", TOOL_APP_ID.to_string());
        unsafe {
            let mut message = [0; 1024];
            let result = sys::SteamAPI_InitFlat(&mut message);
            ensure!(
                result == sys::ESteamAPIInitResult::k_ESteamAPIInitResult_OK,
                "initialize Steamworks as App ID {TOOL_APP_ID}: {} ({result:?}); run Steam and sign in",
                read_string(&message)?
            );
            let steam = Self {
                ugc: sys::SteamAPI_SteamUGC_v021(),
                pipe: sys::SteamAPI_GetHSteamPipe(),
            };
            ensure!(
                !steam.ugc.is_null() && steam.pipe != 0,
                "Steam Workshop interface unavailable"
            );
            sys::SteamAPI_ManualDispatch_Init();
            Ok(steam)
        }
    }

    fn wait<T: CallResult>(&self, call: sys::SteamAPICall_t, timeout: Duration) -> Result<T> {
        self.wait_with_progress(call, timeout, || {})
    }

    fn wait_with_progress<T: CallResult>(
        &self,
        call: sys::SteamAPICall_t,
        timeout: Duration,
        mut report_progress: impl FnMut(),
    ) -> Result<T> {
        ensure!(
            call != sys::k_uAPICallInvalid,
            "Steam rejected the request before submission"
        );
        let started = Instant::now();
        while started.elapsed() < timeout {
            // A matching callback stays valid until FreeLastCallback. CallResult ties the
            // callback number to the layout and size of the corresponding SDK struct.
            unsafe {
                sys::SteamAPI_ManualDispatch_RunFrame(self.pipe);
                let mut message = MaybeUninit::<sys::CallbackMsg_t>::uninit();
                while sys::SteamAPI_ManualDispatch_GetNextCallback(self.pipe, message.as_mut_ptr())
                {
                    let message = message.assume_init();
                    if message.m_iCallback == sys::SteamAPICallCompleted_t_k_iCallback as i32 {
                        let completed = message
                            .m_pubParam
                            .cast::<sys::SteamAPICallCompleted_t>()
                            .read_unaligned();
                        if completed.m_hAsyncCall == call {
                            let mut output = MaybeUninit::<T>::uninit();
                            let mut failed = false;
                            let delivered = sys::SteamAPI_ManualDispatch_GetAPICallResult(
                                self.pipe,
                                call,
                                output.as_mut_ptr().cast(),
                                size_of::<T>() as i32,
                                T::CALLBACK,
                                &mut failed,
                            );
                            sys::SteamAPI_ManualDispatch_FreeLastCallback(self.pipe);
                            ensure!(
                                delivered && !failed,
                                "Steam call result unavailable; outcome unknown"
                            );
                            return Ok(output.assume_init());
                        }
                    }
                    sys::SteamAPI_ManualDispatch_FreeLastCallback(self.pipe);
                }
            }
            report_progress();
            thread::sleep(Duration::from_millis(25));
        }
        anyhow::bail!(
            "Steam timed out after {} seconds; outcome unknown",
            timeout.as_secs()
        )
    }

    fn query(
        &self,
        id: u64,
        language: &'static CStr,
        include_details: bool,
    ) -> Result<ItemQuery<'_>> {
        let mut id_to_query = id;
        unsafe {
            let handle =
                sys::SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest(self.ugc, &mut id_to_query, 1);
            let query = ItemQuery::new(self, handle, language)?;
            check(
                sys::SteamAPI_ISteamUGC_SetReturnLongDescription(self.ugc, handle, true),
                "query full description",
            )?;
            if include_details {
                check(
                    sys::SteamAPI_ISteamUGC_SetReturnChildren(self.ugc, handle, true),
                    "query required items",
                )?;
                query.return_metadata()?;
            }
            let result = query.send()?;
            ensure!(
                result.m_unNumResultsReturned == 1,
                "Steam returned no details for item {id}"
            );
            Ok(query)
        }
    }

    pub fn list_items(&self, limit: u32) -> Result<Vec<ListedItem>> {
        let owner = self.user_id()?;
        // The low 32 bits of a Steam ID are the AccountID used by CreateQueryUserUGCRequest.
        let account_id = owner as u32;
        let mut items = Vec::new();
        let mut seen = BTreeSet::new();
        let mut rows_read = 0;
        for page in 1.. {
            let handle = unsafe {
                sys::SteamAPI_ISteamUGC_CreateQueryUserUGCRequest(
                    self.ugc,
                    account_id,
                    sys::EUserUGCList::k_EUserUGCList_Published,
                    sys::EUGCMatchingUGCType::k_EUGCMatchingUGCType_Items,
                    sys::EUserUGCListSortOrder::k_EUserUGCListSortOrder_CreationOrderDesc,
                    TOOL_APP_ID,
                    GAME_APP_ID,
                    page,
                )
            };
            let query = ItemQuery::new(self, handle, c"english")?;
            query.return_metadata()?;
            let result = query
                .send()
                .with_context(|| format!("list Workshop items, page {page}"))?;
            for index in 0..result.m_unNumResultsReturned {
                let details = query.row(index)?;
                let id = details.m_nPublishedFileId;
                ensure!(
                    id != 0
                        && details.m_nConsumerAppID == GAME_APP_ID,
                    "Steam returned an unexpected item {id} in the account's Workshop list (consumer App ID {})",
                    { details.m_nConsumerAppID }
                );
                if details.m_eFileType != sys::EWorkshopFileType::k_EWorkshopFileTypeCommunity
                    || !seen.insert(id)
                {
                    continue;
                }
                let metadata = query.metadata(index)?;
                let item_owner = if details.m_ulSteamIDOwner == 0 {
                    self.query(id, c"english", false)?
                        .details(id)?
                        .m_ulSteamIDOwner
                } else {
                    details.m_ulSteamIDOwner
                };
                items.push(ListedItem {
                    workshop_id: id,
                    workshop_url: item_url(id),
                    title: read_string(&details.m_rgchTitle)?,
                    created_at: (details.m_rtimeCreated != 0)
                        .then(|| format_utc(i64::from(details.m_rtimeCreated)))
                        .transpose()?,
                    visibility: local_visibility(details.m_eVisibility)?,
                    owned_by_current_account: item_owner == owner,
                    content_bytes: details.m_nFileSize.max(0) as u32,
                    mod_ids: tag_values(&metadata, MOD_ID_TAG)
                        .into_iter()
                        .map(str::to_owned)
                        .collect(),
                });
                if items.len() == limit as usize {
                    return Ok(items);
                }
            }
            rows_read += result.m_unNumResultsReturned;
            if result.m_unNumResultsReturned == 0 || rows_read >= result.m_unTotalMatchingResults {
                break;
            }
        }
        Ok(items)
    }

    fn user_id(&self) -> Result<u64> {
        let user = unsafe { sys::SteamAPI_SteamUser_v023() };
        ensure!(!user.is_null(), "Steam user interface unavailable");
        let id = unsafe { sys::SteamAPI_ISteamUser_GetSteamID(user) };
        ensure!(id != 0, "sign in to Steam to query your Workshop account");
        Ok(id)
    }

    pub fn read_item(&self, id: u64) -> Result<OnlineItem> {
        let english = self
            .query(id, c"english", true)
            .context("query English item details")?;
        let details = english.details(id)?;
        let schinese = self
            .query(id, c"schinese", false)
            .context("query Simplified Chinese item details")?;
        Ok(OnlineItem {
            english: item_copy(&details)?,
            schinese: item_copy(&schinese.details(id)?)?,
            visibility: local_visibility(details.m_eVisibility)?,
            tags: english.tags()?,
            cover_url: english.cover_url()?,
            metadata: english.metadata(0)?,
            dependencies: Dependencies {
                items: english.children(details.m_unNumChildren)?,
                dlc: self.query_dlc(id).context("query required DLC")?,
            },
        })
    }

    fn query_dlc(&self, id: u64) -> Result<BTreeSet<u32>> {
        let call = unsafe { sys::SteamAPI_ISteamUGC_GetAppDependencies(self.ugc, id) };
        let result: sys::GetAppDependenciesResult_t = self.wait(call, QUERY_TIMEOUT)?;
        check_result(result.m_eResult)?;
        ensure!(
            result.m_nPublishedFileId == id,
            "Steam returned DLC for another item"
        );
        let count = result.m_nNumAppDependencies as usize;
        let ids = result.m_rgAppIDs;
        ensure!(
            count == result.m_nTotalNumAppDependencies as usize && count <= ids.len(),
            "Steam returned an incomplete DLC list ({count} of {})",
            { result.m_nTotalNumAppDependencies }
        );
        checked_ids(ids[..count].iter().copied())
    }

    fn submit(
        &self,
        release: &Release,
        id: u64,
        upload: Option<(&Path, Option<&str>)>,
    ) -> Result<bool> {
        let copy = if upload.is_some() {
            &release.config.english
        } else {
            &release.config.schinese
        };
        let language = if upload.is_some() {
            c"english"
        } else {
            c"schinese"
        };
        let title = CString::new(copy.title.as_str())?;
        let description = CString::new(copy.description.as_str())?;
        let note = upload
            .and_then(|(_, note)| note)
            .map(CString::new)
            .transpose()?;
        unsafe {
            let ugc = self.ugc;
            let handle = sys::SteamAPI_ISteamUGC_StartItemUpdate(ugc, GAME_APP_ID, id);
            ensure!(
                handle != sys::k_UGCUpdateHandleInvalid,
                "Steam rejected StartItemUpdate"
            );
            check(
                sys::SteamAPI_ISteamUGC_SetItemUpdateLanguage(ugc, handle, language.as_ptr()),
                "update language",
            )?;
            check(
                sys::SteamAPI_ISteamUGC_SetItemTitle(ugc, handle, title.as_ptr()),
                "title",
            )?;
            check(
                sys::SteamAPI_ISteamUGC_SetItemDescription(ugc, handle, description.as_ptr()),
                "description",
            )?;
            if let Some((staged, _)) = upload {
                let staged = steam_path(staged)?;
                let cover = steam_path(&release.cover)?;
                let tags = release
                    .config
                    .steam_tags()
                    .into_iter()
                    .map(CString::new)
                    .collect::<std::result::Result<Vec<_>, _>>()?;
                let mut pointers = tags.iter().map(|tag| tag.as_ptr()).collect::<Vec<_>>();
                let tags = sys::SteamParamStringArray_t {
                    m_ppStrings: pointers.as_mut_ptr(),
                    m_nNumStrings: pointers.len().try_into()?,
                };
                check(
                    sys::SteamAPI_ISteamUGC_SetItemContent(ugc, handle, staged.as_ptr()),
                    "content folder",
                )?;
                check(
                    sys::SteamAPI_ISteamUGC_SetItemPreview(ugc, handle, cover.as_ptr()),
                    "cover",
                )?;
                check(
                    sys::SteamAPI_ISteamUGC_SetItemVisibility(
                        ugc,
                        handle,
                        steam_visibility(release.config.visibility),
                    ),
                    "visibility",
                )?;
                check(
                    sys::SteamAPI_ISteamUGC_SetItemTags(ugc, handle, &tags, false),
                    "Type and classification tags",
                )?;
                for (key, value) in [
                    (c"ModId", &release.package.mod_id),
                    (c"ModVersion", &release.package.mod_version),
                ] {
                    let value = CString::new(value.as_str())?;
                    check(
                        sys::SteamAPI_ISteamUGC_RemoveItemKeyValueTags(ugc, handle, key.as_ptr()),
                        "previous version tag",
                    )?;
                    check(
                        sys::SteamAPI_ISteamUGC_AddItemKeyValueTag(
                            ugc,
                            handle,
                            key.as_ptr(),
                            value.as_ptr(),
                        ),
                        "version tag",
                    )?;
                }
            }
            let note = note.as_ref().map_or(ptr::null(), |note| note.as_ptr());
            let call = sys::SteamAPI_ISteamUGC_SubmitItemUpdate(ugc, handle, note);
            let result: sys::SubmitItemUpdateResult_t = if upload.is_some() {
                let mut next_report = Instant::now() + UPLOAD_REPORT_INTERVAL;
                let mut last_progress = None;
                self.wait_with_progress(call, UPLOAD_TIMEOUT, || {
                    let now = Instant::now();
                    if now >= next_report {
                        next_report = now + UPLOAD_REPORT_INTERVAL;
                        let (mut processed, mut total) = (0, 0);
                        let status = sys::SteamAPI_ISteamUGC_GetItemUpdateProgress(
                            ugc,
                            handle,
                            &mut processed,
                            &mut total,
                        );
                        let progress = (status, processed, total);
                        if last_progress != Some(progress) {
                            last_progress = Some(progress);
                            report_upload(id, status, processed, total);
                        }
                    }
                })?
            } else {
                self.wait(call, QUERY_TIMEOUT)?
            };
            check_result(result.m_eResult)?;
            ensure!(
                result.m_nPublishedFileId == id,
                "Steam returned an update result for another item; outcome unknown"
            );
            Ok(result.m_bUserNeedsToAcceptWorkshopLegalAgreement)
        }
    }
}

impl Drop for Steam {
    fn drop(&mut self) {
        unsafe { sys::SteamAPI_Shutdown() }
    }
}

impl Publisher for Steam {
    fn create(&self) -> Result<Creation> {
        let call = unsafe {
            sys::SteamAPI_ISteamUGC_CreateItem(
                self.ugc,
                GAME_APP_ID,
                sys::EWorkshopFileType::k_EWorkshopFileTypeCommunity,
            )
        };
        if call == sys::k_uAPICallInvalid {
            return Ok(Creation {
                id: 0,
                legal_agreement: false,
                result: Err(anyhow::anyhow!(
                    "Steam rejected item creation before submission"
                )),
            });
        }
        let result: sys::CreateItemResult_t = self.wait(call, QUERY_TIMEOUT)?;
        let id = result.m_nPublishedFileId;
        if id == 0 && result.m_eResult == EResult::k_EResultTimeout {
            anyhow::bail!("Steam timed out creating the item; outcome unknown");
        }
        Ok(Creation {
            id,
            legal_agreement: result.m_bUserNeedsToAcceptWorkshopLegalAgreement,
            result: check_result(result.m_eResult),
        })
    }

    fn dependencies(&self, id: u64) -> Result<Dependencies> {
        let query = self
            .query(id, c"english", true)
            .context("query required items")?;
        let details = query.details(id)?;
        let owner = self.user_id()?;
        ensure!(
            details.m_ulSteamIDOwner == owner,
            "item {id} is owned by a different Steam account"
        );
        Ok(Dependencies {
            items: query
                .children(details.m_unNumChildren)
                .context("query required items")?,
            dlc: self.query_dlc(id).context("query required DLC")?,
        })
    }

    fn main_update(
        &self,
        release: &Release,
        id: u64,
        staged: &Path,
        note: Option<&str>,
    ) -> Result<bool> {
        self.submit(release, id, Some((staged, note)))
    }

    fn chinese_update(&self, release: &Release, id: u64) -> Result<bool> {
        self.submit(release, id, None)
    }

    fn change_dependency(&self, id: u64, change: Change) -> Result<()> {
        // Each API uses a distinct callback type, even when its payload fields match.
        let (result, parent, dependency, expected) = unsafe {
            match change {
                Change::AddItem(child) => {
                    let result: sys::AddUGCDependencyResult_t = self.wait(
                        sys::SteamAPI_ISteamUGC_AddDependency(self.ugc, id, child),
                        QUERY_TIMEOUT,
                    )?;
                    (
                        result.m_eResult,
                        result.m_nPublishedFileId,
                        result.m_nChildPublishedFileId,
                        child,
                    )
                }
                Change::RemoveItem(child) => {
                    let result: sys::RemoveUGCDependencyResult_t = self.wait(
                        sys::SteamAPI_ISteamUGC_RemoveDependency(self.ugc, id, child),
                        QUERY_TIMEOUT,
                    )?;
                    (
                        result.m_eResult,
                        result.m_nPublishedFileId,
                        result.m_nChildPublishedFileId,
                        child,
                    )
                }
                Change::AddDlc(app) => {
                    let result: sys::AddAppDependencyResult_t = self.wait(
                        sys::SteamAPI_ISteamUGC_AddAppDependency(self.ugc, id, app),
                        QUERY_TIMEOUT,
                    )?;
                    (
                        result.m_eResult,
                        result.m_nPublishedFileId,
                        result.m_nAppID.into(),
                        app.into(),
                    )
                }
                Change::RemoveDlc(app) => {
                    let result: sys::RemoveAppDependencyResult_t = self.wait(
                        sys::SteamAPI_ISteamUGC_RemoveAppDependency(self.ugc, id, app),
                        QUERY_TIMEOUT,
                    )?;
                    (
                        result.m_eResult,
                        result.m_nPublishedFileId,
                        result.m_nAppID.into(),
                        app.into(),
                    )
                }
            }
        };
        check_result(result)?;
        ensure!(
            parent == id && dependency == expected,
            "Steam returned a result for another dependency; outcome unknown"
        );
        Ok(())
    }
}

pub struct OnlineItem {
    pub english: LocalizedText,
    pub schinese: LocalizedText,
    pub visibility: Visibility,
    pub tags: Vec<String>,
    pub cover_url: Option<String>,
    pub metadata: Vec<(String, String)>,
    pub dependencies: Dependencies,
}

#[derive(Serialize)]
pub struct ListedItem {
    workshop_id: u64,
    workshop_url: String,
    title: String,
    created_at: Option<String>,
    visibility: Visibility,
    owned_by_current_account: bool,
    content_bytes: u32,
    mod_ids: Vec<String>,
}

struct ItemQuery<'a> {
    steam: &'a Steam,
    handle: sys::UGCQueryHandle_t,
}

impl<'a> ItemQuery<'a> {
    fn new(steam: &'a Steam, handle: sys::UGCQueryHandle_t, language: &CStr) -> Result<Self> {
        ensure!(
            handle != sys::k_UGCQueryHandleInvalid,
            "Steam rejected the Workshop query"
        );
        let query = Self { steam, handle };
        unsafe {
            check(
                sys::SteamAPI_ISteamUGC_SetLanguage(steam.ugc, handle, language.as_ptr()),
                "query language",
            )?;
            check(
                sys::SteamAPI_ISteamUGC_SetAllowCachedResponse(steam.ugc, handle, 0),
                "query cache policy",
            )?;
        }
        Ok(query)
    }

    fn return_metadata(&self) -> Result<()> {
        check(
            unsafe {
                sys::SteamAPI_ISteamUGC_SetReturnKeyValueTags(self.steam.ugc, self.handle, true)
            },
            "query key-value tags",
        )
    }

    fn send(&self) -> Result<sys::SteamUGCQueryCompleted_t> {
        let call =
            unsafe { sys::SteamAPI_ISteamUGC_SendQueryUGCRequest(self.steam.ugc, self.handle) };
        let result: sys::SteamUGCQueryCompleted_t = self.steam.wait(call, QUERY_TIMEOUT)?;
        check_result(result.m_eResult)?;
        ensure!(
            result.m_handle == self.handle,
            "Steam returned results for another query"
        );
        Ok(result)
    }

    fn row(&self, index: u32) -> Result<sys::SteamUGCDetails_t> {
        let mut details = MaybeUninit::uninit();
        let details = unsafe {
            check(
                sys::SteamAPI_ISteamUGC_GetQueryUGCResult(
                    self.steam.ugc,
                    self.handle,
                    index,
                    details.as_mut_ptr(),
                ),
                "item details",
            )?;
            details.assume_init()
        };
        let id = details.m_nPublishedFileId;
        check_result(details.m_eResult).with_context(|| format!("read Steam item {id}"))?;
        Ok(details)
    }

    fn details(&self, id: u64) -> Result<sys::SteamUGCDetails_t> {
        let details = self.row(0)?;
        ensure!(
            details.m_nPublishedFileId == id,
            "Steam returned details for another item"
        );
        ensure!(
            details.m_nConsumerAppID == GAME_APP_ID,
            "item {id} does not belong to the Civilization VI Workshop"
        );
        ensure!(
            details.m_eFileType == sys::EWorkshopFileType::k_EWorkshopFileTypeCommunity,
            "item {id} is not a community Workshop item"
        );
        Ok(details)
    }

    fn children(&self, count: u32) -> Result<BTreeSet<u64>> {
        if count == 0 {
            return Ok(BTreeSet::new());
        }
        let mut ids = vec![0; count as usize];
        check(
            unsafe {
                sys::SteamAPI_ISteamUGC_GetQueryUGCChildren(
                    self.steam.ugc,
                    self.handle,
                    0,
                    ids.as_mut_ptr(),
                    count,
                )
            },
            "required items",
        )?;
        checked_ids(ids)
    }

    fn tags(&self) -> Result<Vec<String>> {
        unsafe {
            let ugc = self.steam.ugc;
            let count = sys::SteamAPI_ISteamUGC_GetQueryUGCNumTags(ugc, self.handle, 0);
            (0..count)
                .map(|index| {
                    let mut tag = [0; 256];
                    check(
                        sys::SteamAPI_ISteamUGC_GetQueryUGCTag(
                            ugc,
                            self.handle,
                            0,
                            index,
                            tag.as_mut_ptr(),
                            tag.len() as u32,
                        ),
                        "classification tag",
                    )?;
                    read_string(&tag)
                })
                .collect()
        }
    }

    fn metadata(&self, item_index: u32) -> Result<Vec<(String, String)>> {
        unsafe {
            let ugc = self.steam.ugc;
            let count =
                sys::SteamAPI_ISteamUGC_GetQueryUGCNumKeyValueTags(ugc, self.handle, item_index);
            (0..count)
                .map(|index| {
                    let mut key = [0; 256];
                    let mut value = [0; 256];
                    check(
                        sys::SteamAPI_ISteamUGC_GetQueryUGCKeyValueTag(
                            ugc,
                            self.handle,
                            item_index,
                            index,
                            key.as_mut_ptr(),
                            key.len() as u32,
                            value.as_mut_ptr(),
                            value.len() as u32,
                        ),
                        "key-value tag",
                    )?;
                    Ok((read_string(&key)?, read_string(&value)?))
                })
                .collect()
        }
    }

    fn cover_url(&self) -> Result<Option<String>> {
        let mut url = [0; 4096];
        let has_preview = unsafe {
            sys::SteamAPI_ISteamUGC_GetQueryUGCPreviewURL(
                self.steam.ugc,
                self.handle,
                0,
                url.as_mut_ptr(),
                url.len() as u32,
            )
        };
        Ok(has_preview
            .then(|| read_string(&url))
            .transpose()?
            .filter(|url| !url.is_empty()))
    }
}

impl Drop for ItemQuery<'_> {
    fn drop(&mut self) {
        unsafe {
            sys::SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(self.steam.ugc, self.handle);
        }
    }
}

fn item_copy(details: &sys::SteamUGCDetails_t) -> Result<LocalizedText> {
    Ok(LocalizedText {
        title: read_string(&details.m_rgchTitle)?,
        description: read_string(&details.m_rgchDescription)?,
    })
}

pub fn item_url(id: u64) -> String {
    format!("https://steamcommunity.com/sharedfiles/filedetails/?id={id}")
}

pub fn tag_values<'a>(metadata: &'a [(String, String)], name: &str) -> BTreeSet<&'a str> {
    metadata
        .iter()
        .filter_map(|(key, value)| key.eq_ignore_ascii_case(name).then_some(value.as_str()))
        .collect()
}

fn format_utc(seconds: i64) -> Result<String> {
    Ok(OffsetDateTime::from_unix_timestamp(seconds)?.format(&Rfc3339)?)
}

fn report_upload(id: u64, status: UploadStatus, processed: u64, total: u64) {
    let stage = match status {
        UploadStatus::k_EItemUpdateStatusPreparingConfig => "preparing settings",
        UploadStatus::k_EItemUpdateStatusPreparingContent => "preparing files",
        UploadStatus::k_EItemUpdateStatusUploadingContent => "uploading files",
        UploadStatus::k_EItemUpdateStatusUploadingPreviewFile => "uploading cover",
        UploadStatus::k_EItemUpdateStatusCommittingChanges => "committing changes",
        _ => return,
    };
    if total > 0 {
        eprintln!("Workshop item {id} | {stage} ({processed}/{total} bytes)");
    } else {
        eprintln!("Workshop item {id} | {stage}");
    }
}

fn read_string(buffer: &[c_char]) -> Result<String> {
    // Steam uses fixed-size C buffers; bound the search for NUL to the supplied array.
    let bytes = unsafe { std::slice::from_raw_parts(buffer.as_ptr().cast::<u8>(), buffer.len()) };
    Ok(CStr::from_bytes_until_nul(bytes)?.to_str()?.to_owned())
}

fn steam_path(path: &Path) -> Result<CString> {
    let path = dunce::simplified(path);
    let value = path
        .to_str()
        .with_context(|| format!("path is not UTF-8: {}", path.display()))?;
    Ok(CString::new(value)?)
}

fn checked_ids<T: Ord + Copy + Default>(ids: impl IntoIterator<Item = T>) -> Result<BTreeSet<T>> {
    let mut set = BTreeSet::new();
    for id in ids {
        ensure!(
            id != T::default() && set.insert(id),
            "Steam returned an incomplete or invalid dependency list"
        );
    }
    Ok(set)
}

fn local_visibility(visibility: RawVisibility) -> Result<Visibility> {
    Ok(match visibility {
        RawVisibility::k_ERemoteStoragePublishedFileVisibilityPublic => Visibility::Public,
        RawVisibility::k_ERemoteStoragePublishedFileVisibilityFriendsOnly => {
            Visibility::FriendsOnly
        }
        RawVisibility::k_ERemoteStoragePublishedFileVisibilityPrivate => Visibility::Private,
        RawVisibility::k_ERemoteStoragePublishedFileVisibilityUnlisted => Visibility::Unlisted,
        other => anyhow::bail!("unsupported Steam visibility {other:?}"),
    })
}

fn steam_visibility(visibility: Visibility) -> RawVisibility {
    match visibility {
        Visibility::Public => RawVisibility::k_ERemoteStoragePublishedFileVisibilityPublic,
        Visibility::FriendsOnly => {
            RawVisibility::k_ERemoteStoragePublishedFileVisibilityFriendsOnly
        }
        Visibility::Private => RawVisibility::k_ERemoteStoragePublishedFileVisibilityPrivate,
        Visibility::Unlisted => RawVisibility::k_ERemoteStoragePublishedFileVisibilityUnlisted,
    }
}

fn check(accepted: bool, field: &str) -> Result<()> {
    ensure!(accepted, "Steam rejected {field}");
    Ok(())
}

fn check_result(result: EResult) -> Result<()> {
    ensure!(
        result != EResult::k_EResultTimeout,
        "Steam reported a timeout; outcome unknown"
    );
    ensure!(result == EResult::k_EResultOK, "Steam returned {result:?}");
    Ok(())
}

/// # Safety
/// Implementations must use the callback number for the exact SDK struct implementing it.
unsafe trait CallResult {
    const CALLBACK: i32;
}

macro_rules! call_results {
    ($($ty:ident => $callback:ident),+ $(,)?) => {$ (
        unsafe impl CallResult for sys::$ty {
            const CALLBACK: i32 = sys::$callback as i32;
        }
    )+};
}

call_results! {
    CreateItemResult_t => CreateItemResult_t_k_iCallback,
    SubmitItemUpdateResult_t => SubmitItemUpdateResult_t_k_iCallback,
    SteamUGCQueryCompleted_t => SteamUGCQueryCompleted_t_k_iCallback,
    GetAppDependenciesResult_t => GetAppDependenciesResult_t_k_iCallback,
    AddUGCDependencyResult_t => AddUGCDependencyResult_t_k_iCallback,
    RemoveUGCDependencyResult_t => RemoveUGCDependencyResult_t_k_iCallback,
    AddAppDependencyResult_t => AddAppDependencyResult_t_k_iCallback,
    RemoveAppDependencyResult_t => RemoveAppDependencyResult_t_k_iCallback,
}
