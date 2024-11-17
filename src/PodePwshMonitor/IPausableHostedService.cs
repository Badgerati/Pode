public interface IPausableHostedService
{
    void OnPause();
    void OnContinue();
}