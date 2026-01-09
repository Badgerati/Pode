using System;
using System.IO;
using System.Threading.Tasks;
using Pode.Sockets.Contexts;
using Pode.Requests;
using Pode.Utilities;

namespace Pode.Responses
{
    public class PodeResponse : PodeProtocol, IDisposable
    {
        public virtual int StatusCode { get; set; } = 0;
        public virtual string StatusDescription { get; set; } = string.Empty;

        public bool SendChunked = false;
        public bool IsSent { get; protected set; } = false;
        public bool IsDisposed { get; private set; }

        // upgrade status for the response (e.g. WebSockets, SSE, etc.)
        public PodeUpgradeStatus ConnectionUpgradeStatus { get; protected set; } = PodeUpgradeStatus.None;

        public PodeContext Context { get; private set; }
        protected PodeRequestHandler Request { get => Context.Request; }

        public PodeResponse(PodeContext context)
        {
            Context = context;
        }

        public virtual async Task Send()
        {
            if (IsSent || IsDisposed)
            {
                return;
            }

            IsSent = true;

            if (StatusCode > 0)
            {
                await WriteLine($"{StatusCode} {StatusDescription}", true).ConfigureAwait(false);
            }
        }

        public virtual async Task Timeout()
        {
            if (IsSent || IsDisposed)
            {
                return;
            }

            IsSent = true;

            if (StatusCode > 0)
            {
                await WriteLine($"{StatusCode} {StatusDescription}", true).ConfigureAwait(false);
            }
        }

        public virtual async Task Acknowledge(string message)
        {
            if (IsSent || IsDisposed || string.IsNullOrWhiteSpace(message))
            {
                return;
            }

            await WriteLine(message, true).ConfigureAwait(false);
        }

        public async Task Flush()
        {
            await Request.Flush().ConfigureAwait(false);
        }

        public async Task<bool> WriteLine(string message, bool flush = false)
        {
            return await Write(PodeHelpers.Encoding.GetBytes($"{message}{PodeHelpers.NEW_LINE}"), flush).ConfigureAwait(false);
        }

        public async Task<bool> Write(byte[] buffer, bool flush = false)
        {
            // write a byte array to the actual client stream
            return await Request.Write(buffer, Context.Listener.CancellationToken, flush);
        }

        public async Task WriteFile(string path)
        {
            await WriteFile(new FileInfo(path)).ConfigureAwait(false);
        }

        public virtual async Task WriteFile(FileSystemInfo file)
        {
            if (IsDisposed)
            {
                return;
            }

            var fileInfo = PodeHelpers.FileExists(file);

            using (var fileStream = fileInfo.OpenRead())
            {
                await Request.Write(fileStream, Context.Listener.CancellationToken).ConfigureAwait(false);
            }
        }

        public virtual void Dispose()
        {
            if (IsDisposed)
            {
                return;
            }

            IsDisposed = true;
            GC.SuppressFinalize(this);
            PodeHelpers.WriteErrorMessage($"Response disposed", Context.Listener, PodeLoggingLevel.Verbose, Context);
        }
    }
}