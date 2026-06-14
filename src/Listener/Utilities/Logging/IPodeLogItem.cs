namespace Pode.Utilities.Logging
{
    public interface IPodeLogItem
    {
        object Items { get; set; }
        object RawItems { get; set; }
    }
}