using System;
using System.IO;
using System.Security.Claims;
using Kerberos.NET;
using Kerberos.NET.Crypto;

namespace Pode
{
    public class PodeKerberosAuth
    {
        private string KeytabPath { get; set; }
        private KeyTable Keytab { get; set; }
        private KerberosAuthenticator Authenticator { get; set; }
        private KerberosValidator Validator { get; set; }

        public PodeKerberosAuth(string keytabPath)
        {
            KeytabPath = keytabPath;
            Keytab = new KeyTable(File.ReadAllBytes(KeytabPath));
            Authenticator = new KerberosAuthenticator(Keytab);

            Validator = new KerberosValidator(Keytab)
            {
                ValidateAfterDecrypt = ValidationActions.Pac
            };
        }

        public void Validate(string token)
        {
            // error if token not provided
            if (string.IsNullOrWhiteSpace(token))
            {
                throw new ArgumentNullException(nameof(token));
            }

            // trim token and get the last part if it contains spaces
            token = token.Trim();
            if (token.IndexOf(' ') >= 1)
            {
                var split = token.Split(' ');
                token = split[split.Length - 1];
            }

            // validate the token
            Validator.Validate(Convert.FromBase64String(token)).Wait();
        }

        public ClaimsPrincipal Authenticate(string token)
        {
            var claims = Authenticator.Authenticate(token);
            claims.Wait();
            return new ClaimsPrincipal(claims.Result);
        }
    }
}