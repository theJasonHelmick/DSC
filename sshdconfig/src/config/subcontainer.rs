use crate::config::match_data::MatchData;
use std::collections::HashMap;

pub enum KeywordType {
    KeywordValue(String),
    RepeatValue(RepeatData),
    MatchValue(MatchData)
}

pub struct SubContainer {
    pub keyword: String,
    pub args: KeywordType,
    pub is_default: bool,
}

pub struct RepeatData {
    pub repeat_lookup: HashMap<Option<String>, String>
}

pub enum UpdateKind {
    Add,
    Modify,
    Remove
}
