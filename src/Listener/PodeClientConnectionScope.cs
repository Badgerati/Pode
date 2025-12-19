namespace Pode
{
    public enum PodeClientConnectionScope
    {
        None,   // used for no scope, e.g. for PodeServerEvent that is not scoped
        Local,  // connection only lives for the duration of a single request
        Global  // connection is cached, and lives beyond a single request until closed or timed out
    }
}