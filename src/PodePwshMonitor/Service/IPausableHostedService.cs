namespace Pode.Service
{
    public interface IPausableHostedService
    {
        void OnPause();
        void OnContinue();
    }
}