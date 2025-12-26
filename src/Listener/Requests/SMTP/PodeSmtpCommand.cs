namespace Pode.Requests.SMTP
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
        MailFrom,
        NoOp,
        Reset
    }
}