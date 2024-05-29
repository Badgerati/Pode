using System;
using System.IO;
using System.Security.Claims;
using Kerberos.NET;
using Kerberos.NET.Crypto;

namespace Pode
{
    public class PodeKerberosAuth
    {
        private string KeyTabPath { get; set; }
        private KeyTable KeyTab { get; set; }
        private KerberosAuthenticator Authenticator { get; set; }
        private KerberosValidator Validator { get; set; }

        public PodeKerberosAuth(string keyTabPath)
        {
            KeyTabPath = keyTabPath;
            KeyTab = new KeyTable(File.ReadAllBytes(keyTabPath));
            Authenticator = new KerberosAuthenticator(KeyTab);

            Validator = new KerberosValidator(KeyTab);
            Validator.ValidateAfterDecrypt = ValidationActions.Pac;
        }

        public void Validate(string token)
        {
            token = token?.Trim();
            if (token.IndexOf(' ') >= 1)
            {
                var split = token.Split(' ');
                token = split[split.Length - 1];
            }

            var result = Validator.Validate(Convert.FromBase64String(token));
            result.Wait();
        }

        public ClaimsPrincipal Authenticate(string token)
        {
            var claims = Authenticator.Authenticate(token);
            claims.Wait();
            return new ClaimsPrincipal(claims.Result);
        }
    }
}