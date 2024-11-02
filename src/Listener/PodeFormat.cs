using System;
using System.Collections;
using System.Text;
using System.Text.RegularExpressions;

namespace Pode
{
    public static class PodeFormat
    {
        /// <summary>
        /// Helper function to sanitize input by returning a default value if the input is null or whitespace.
        /// </summary>
        /// <param name="value">The object value to be sanitized.</param>
        /// <returns>A sanitized string, or "-" if the input is null or whitespace.</returns>
        private static string Sanitize(object value)
        {
            return value == null || string.IsNullOrWhiteSpace(value.ToString()) ? "-" : value.ToString();
        }

        /// <summary>
        /// Formats error log entries based on the provided options. Includes details like Date, Level, ThreadId, Server, Category, Message, and StackTrace.
        /// </summary>
        /// <param name="item">A hashtable containing log details.</param>
        /// <param name="options">A hashtable containing format options such as Levels, Raw, and DataFormat.</param>
        /// <returns>A formatted log string, or the original item if Raw is specified, or null if Level is not in options.Levels.</returns>
        public static object ErrorsLog(Hashtable item, Hashtable options)
        {
            // Check if required keys are present and valid
            if (item == null || options == null) return null;
            if (!item.ContainsKey("Level") || !item.ContainsKey("Date") || !item.ContainsKey("ThreadId") ||
                !item.ContainsKey("Server") || !item.ContainsKey("Category") || !item.ContainsKey("Message") || !item.ContainsKey("StackTrace"))
            {
                return null;
            }

            // Check if the error level is present in the options' Levels array
            if (options.ContainsKey("Levels") && !((IList)options["Levels"]).Contains(item["Level"]))
            {
                return null;
            }

            // Return the raw item if Raw is set
            if (options.ContainsKey("Raw") && (bool)options["Raw"])
            {
                return item;
            }

            // Retrieve data format or default to a basic date format
            string dataFormat = options.ContainsKey("DataFormat") ? options["DataFormat"].ToString() : "yyyy-MM-dd HH:mm:ss";

            // Construct the log entry with specified fields
            StringBuilder sb = new StringBuilder();
            return sb.Append("Date: ").Append(((DateTime)item["Date"]).ToString(dataFormat)).Append(" Level: ").Append(Sanitize(item["Level"]))
                     .Append(" ThreadId: ").Append(Sanitize(item["ThreadId"])).Append(" Server: ").Append(Sanitize(item["Server"])).Append(" Category: ")
                     .Append(Sanitize(item["Category"])).Append(" Message: ").Append(Sanitize(item["Message"])).Append(" StackTrace: ")
                     .Append(Sanitize(item["StackTrace"])).ToString();
        }

        /// <summary>
        /// Formats request log entries based on the provided log format in options. Supports "extended", "common", "json", and "combined" formats.
        /// </summary>
        /// <param name="item">A hashtable containing request log details.</param>
        /// <param name="options">A hashtable containing format options such as LogFormat and Raw.</param>
        /// <returns>A formatted request log string, or the original item if Raw is specified.</returns>
        public static object RequestLog(Hashtable item, Hashtable options)
        {
            if (item == null || options == null) return null;

            // Return the raw item if Raw is set
            if (options.ContainsKey("Raw") && (bool)options["Raw"])
            {
                return item;
            }

            // Retrieve log format or default to "combined"
            string logFormat = options.ContainsKey("LogFormat") ? options["LogFormat"].ToString().ToLowerInvariant() : "combined";

            // Construct the log entry based on the specified format
            StringBuilder sb = new StringBuilder();

            switch (logFormat)
            {
                case "extended":
                    if (item.ContainsKey("Host") && item.ContainsKey("User") && item.ContainsKey("Request") && item.ContainsKey("Response") &&
                        item["Request"] is Hashtable requestExtended && item["Response"] is Hashtable responseExtended)
                    {
                        return sb.Append(((DateTime)item["Date"]).ToString("yyyy-MM-dd")).Append(" ").Append(((DateTime)item["Date"]).ToString("HH:mm:ss")).Append(" ")
                            .Append(Sanitize(item["Host"])).Append(" ").Append(Sanitize(item["RfcUserIdentity"])).Append(" ")
                            .Append(Sanitize(item["User"])).Append(" ").Append(Sanitize(requestExtended["Method"])).Append(" ")
                            .Append(Sanitize(requestExtended["Resource"])).Append(" ").Append("- ").Append(Sanitize(responseExtended["StatusCode"])).Append(" ")
                            .Append(Sanitize(responseExtended["Size"])).Append(" ").Append("\"").Append(Sanitize(requestExtended["Agent"])).Append("\"")
                            .ToString();
                    }
                    break;

                case "common":
                    if (item.ContainsKey("Host") && item.ContainsKey("RfcUserIdentity") && item.ContainsKey("User") && item.ContainsKey("Request") && item.ContainsKey("Response") &&
                        item["Request"] is Hashtable requestCommon && item["Response"] is Hashtable responseCommon)
                    {
                        return sb.Append(Sanitize(item["Host"])).Append(" ").Append(Sanitize(item["RfcUserIdentity"])).Append(" ").Append(Sanitize(item["User"])).Append(" [")
                            .Append(Regex.Replace(((DateTime)item["Date"]).ToString("dd/MMM/yyyy:HH:mm:ss zzz"), @"([+-]\d{2}):(\d{2})", "$1$2")).Append("] \"")
                            .Append(Sanitize(requestCommon["Method"])).Append(" ").Append(Sanitize(requestCommon["Resource"])).Append(" ")
                            .Append(Sanitize(requestCommon["Protocol"])).Append("\" ").Append(Sanitize(responseCommon["StatusCode"]))
                            .Append(" ").Append(Sanitize(responseCommon["Size"])).ToString();
                    }
                    break;

                case "json":
                    if (item.ContainsKey("Host") && item.ContainsKey("User") && item.ContainsKey("Request") && item.ContainsKey("Response") &&
                        item["Request"] is Hashtable requestJson && item["Response"] is Hashtable responseJson)
                    {
                        return sb.Append("{\"time\": \"").Append(((DateTime)item["Date"]).ToString("yyyy-MM-ddTHH:mm:ssK")).Append("\",\"remote_ip\": \"")
                            .Append(Sanitize(item["Host"])).Append("\",\"user\": \"").Append(Sanitize(item["User"])).Append("\",\"method\": \"")
                            .Append(Sanitize(requestJson["Method"])).Append("\",\"uri\": \"").Append(Sanitize(requestJson["Resource"]))
                            .Append("\",\"query\": \"").Append(Sanitize(requestJson["Query"])).Append("\",\"status\": ")
                            .Append(Sanitize(responseJson["StatusCode"])).Append(",\"response_size\": ")
                            .Append(Sanitize(responseJson["Size"])).Append(",\"user_agent\": \"").Append(Sanitize(requestJson["Agent"]))
                            .Append("\"}").ToString();
                    }
                    break;

                default:
                    if (item.ContainsKey("Host") && item.ContainsKey("RfcUserIdentity") && item.ContainsKey("User") && item.ContainsKey("Request") && item.ContainsKey("Response") &&
                        item["Request"] is Hashtable requestCombined && item["Response"] is Hashtable responseCombined)
                    {
                        return sb.Append(Sanitize(item["Host"])).Append(" ").Append(Sanitize(item["RfcUserIdentity"])).Append(" ").Append(Sanitize(item["User"])).Append(" [")
                            .Append(Regex.Replace(((DateTime)item["Date"]).ToString("dd/MMM/yyyy:HH:mm:ss zzz"), @"([+-]\d{2}):(\d{2})", "$1$2")).Append("] \"")
                            .Append(Sanitize(requestCombined["Method"])).Append(" ").Append(Sanitize(requestCombined["Resource"])).Append(" ")
                            .Append(Sanitize(requestCombined["Protocol"])).Append("\" ").Append(Sanitize(responseCombined["StatusCode"]))
                            .Append(" ").Append(Sanitize(responseCombined["Size"])).Append(" \"")
                            .Append(Sanitize(requestCombined["Referrer"])).Append("\" \"").Append(Sanitize(requestCombined["Agent"])).Append("\"")
                            .ToString();
                    }
                    break;
            }
            return null;
        }

        /// <summary>
        /// Formats general log entries, checking for level filtering and the presence of required fields.
        /// </summary>
        /// <param name="item">A hashtable containing general log details.</param>
        /// <param name="options">A hashtable containing format options such as Levels, Raw, and DataFormat.</param>
        /// <returns>A formatted general log string, or the original item if Raw is specified, or null if Level is not in options.Levels.</returns>
        public static object GeneralLog(Hashtable item, Hashtable options)
        {
            if (item == null || options == null) return null;

            // Check if the error level is present in the options' Levels array
            if (options.ContainsKey("Levels") && !((IList)options["Levels"]).Contains(item["Level"]))
            {
                return null;
            }

            // Return the raw item if Raw is set
            if (options.ContainsKey("Raw") && (bool)options["Raw"])
            {
                return item;
            }

            // Retrieve data format or default to a basic date format
            string dataFormat = options.ContainsKey("DataFormat") ? options["DataFormat"].ToString() : "yyyy-MM-dd HH:mm:ss";

            // Construct the log entry with specified fields
            StringBuilder sb = new StringBuilder();
            return sb.Append("[").Append(((DateTime)item["Date"]).ToString(dataFormat)).Append("] ")
                     .Append(Sanitize(item["Level"])).Append(" ").Append(Sanitize(item["Tag"])).Append(" ").Append(Sanitize(item["ThreadId"])).Append(" ").Append(Sanitize(item["Message"]))
                     .ToString();
        }
    }
}
