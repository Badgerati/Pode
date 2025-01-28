using System;

namespace PodeMonitor
{
    public static class PodeServiceStateExtensions
    {
        /// <summary>
        /// Converts a string to a PodeMonitorServiceState enum in a case-insensitive manner.
        /// </summary>
        /// <param name="stateString">The string representation of the state.</param>
        /// <returns>The corresponding PodeMonitorServiceState, or Unknown if parsing fails.</returns>
        public static PodeMonitorServiceState ToPodeMonitorServiceState(this string stateString)
        {
            if (Enum.TryParse(stateString, true, out PodeMonitorServiceState result)) // true for case-insensitive
            {
                return result;
            }
            return PodeMonitorServiceState.Unknown; // Default if parsing fails
        }

        /// <summary>
        /// Converts a PodeMonitorServiceState enum to its string representation.
        /// </summary>
        /// <param name="state">The PodeMonitorServiceState enum value.</param>
        /// <returns>The string representation of the state.</returns>
        public static string ToPodeMonitorServiceStateString(this PodeMonitorServiceState state)
        {
            return state.ToString();
        }
    }
}
