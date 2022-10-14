import dimscord

let checkListEmoji* : string = "✅"

let everyoneDeniedPermissions* : set[PermissionFlags] = {
    permViewChannel
    , permVoiceConnect
    , permMentionEveryone 
    , permManageGuild
    , permAdministrator
}

let approvedMemberAllowedPermissions* : set[PermissionFlags] = {
    permViewChannel
    , permVoiceConnect
    , permAddReactions
    , permSendMessages
}

let approvedMemberDeniedPermissions* : set[PermissionFlags] = {
    permMentionEveryone 
    , permManageGuild
    , permAdministrator
}