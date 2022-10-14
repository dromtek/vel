import 
    std/db_sqlite
    , options

# This way to make key value like using SQL for feature configuration
type 
    StateContext* {. pure .} = enum 
        ctxMemberVerification = "ctxMemberVerification"
        ctxWatashiFeature = "ctxWatashiFeature"

    StateLabel* {. pure .} = enum
        MemberVerificationRole = "memberVerificationRole"
        MemberVerificationMessage = "memberVerificationMessage"
        AllowedRoleList = "allowedRoleList"
    
    stateData* = object 
        context*: StateContext
        key*: StateLabel
        value*: string
        guildID*: string

    stateQuery* = object 
        context*: StateContext
        key*: StateLabel
        guildID*: string

    IStateRepository* = concept s
        s.sqlDb is DbConn
        s.findStateByStateQuery(q: stateQuery) is Option[stateData]
        s.createState(d: stateData) is bool
        s.destroyStateByStateQuery(q: stateQuery) is bool

proc newStateData*(context: StateContext, key: StateLabel,value,guildID: string) : stateData = 
    result.context = context
    result.key = key
    result.value = value
    result.guildID = guildID