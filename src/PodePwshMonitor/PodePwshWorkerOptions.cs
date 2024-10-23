namespace Pode.Services
{
    public class PodePwshWorkerOptions
    {
        public string ScriptPath { get; set; }
        public string PwshPath { get; set; }
        public string ParameterString { get; set; } = "";
        public string LogFilePath { get; set; } = "";
        public bool Quiet { get; set; } = true;
        public bool DisableTermination { get; set; } = true;
        public int ShutdownWaitTimeMs { get; set; } = 30000;

        public override string ToString()
        {
            return $"ScriptPath: {ScriptPath}, PwshPath: {PwshPath}, ParameterString: {ParameterString}, " +
                   $"LogFilePath: {LogFilePath}, Quiet: {Quiet}, DisableTermination: {DisableTermination}, " +
                   $"ShutdownWaitTimeMs: {ShutdownWaitTimeMs}";
        }
    }
}
