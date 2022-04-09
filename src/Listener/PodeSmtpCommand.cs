namespace Pode
{
    public enum PodeSmtpCommand
    {
        None,
        Ehlo,
        Helo,
        Data,
        Quit,
        StartTls,
        RcptTo,
        MailFrom
    }
}