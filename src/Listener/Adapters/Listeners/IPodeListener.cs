using System.Threading;
using System.Threading.Tasks;
using Pode.Transport.Sockets;
using Pode.Utilities;
using Pode.Protocols.Common.Contexts;

namespace Pode.Adapters.Listeners
{
    public interface IPodeListener : IPodeAdapter
    {
        PodeItemQueue<PodeContext> Contexts { get; }

        int RequestTimeout { get; set; }
        int RequestBodySize { get; set; }
        bool ShowServerDetails { get; set; }

        void Add(PodeSocket socket);

        PodeContext GetContext(CancellationToken cancellationToken = default);
        Task<PodeContext> GetContextAsync(CancellationToken cancellationToken = default);
        void AddContext(PodeContext context);
        void RemoveProcessingContext(PodeContext context);
    }
}