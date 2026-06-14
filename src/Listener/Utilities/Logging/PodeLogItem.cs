namespace Pode.Utilities.Logging
{
    public class PodeLogItem : IPodeLogItem
    {
        public object Items { get; set; }
        public object RawItems { get; set; }

        public PodeLogItem(object items, object rawItems)
        {
            Items = items;
            RawItems = rawItems;
        }
    }
}