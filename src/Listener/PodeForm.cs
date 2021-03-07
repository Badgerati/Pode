using System;
using System.Collections.Generic;

namespace Pode
{
    public class PodeForm
    {
        public IList<PodeFormFile> Files { get; private set; }
        public IList<PodeFormData> Data { get; private set; }

        public PodeForm()
        {
            Files = new List<PodeFormFile>();
            Data = new List<PodeFormData>();
        }
    }
}