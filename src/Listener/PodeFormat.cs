using System;
using System.Collections.Concurrent;
using System.Collections;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Pode
{
    public static class PodeFormat
    {
        // Helper function to sanitize and return a default value if the input is null or whitespace
        private static string Sanitize(object value)
        {
            return value == null || string.IsNullOrWhiteSpace(value.ToString()) ? "-" : value.ToString();
        }

        public static object ErrorsLog(Hashtable item, Hashtable options)
        {
            // Do nothing if the error level isn't present in the options' Levels array
            if (options.ContainsKey("Levels") && !((IList)options["Levels"]).Contains(item["Level"]))
            {
                return null;
            }

            // Just return the item if Raw is set
            if (options.ContainsKey("Raw") && (bool)options["Raw"])
            {
                return item;
            }

            // Optimized concatenation using StringBuilder
            StringBuilder sb = new StringBuilder();
            return sb.Append("Date: ").Append(((DateTime)item["Date"]).ToString(options["DataFormat"].ToString())).Append(" Level: ").Append(item["Level"])
                     .Append(" ThreadId: ").Append(item["ThreadId"]).Append(" Server: ").Append(item["Server"]).Append(" Category: ")
                     .Append(item["Category"]).Append(" Message: ").Append(item["Message"]).Append(" StackTrace: ").Append(item["StackTrace"])
                     .ToString();
        }

        public static object RequestLog(Hashtable item, Hashtable options)
        {
            // Just return the item if Raw is set
            if (options.ContainsKey("Raw") && (bool)options["Raw"])
            {
                return item;
            }

            StringBuilder sb = new StringBuilder();
            string logFormat = options.ContainsKey("LogFormat") ? options["LogFormat"].ToString().ToLowerInvariant() : "combined";

            switch (logFormat)
            {
                case "extended":
                    return sb.Append("Date: ").Append(((DateTime)item["Date"]).ToString("yyyy-MM-dd")).Append(" ").Append(((DateTime)item["Date"]).ToString("HH:mm:ss")).Append(" ")
                        .Append(Sanitize(item["Host"])).Append(" ").Append(Sanitize(item["User"])).Append(" ").Append(Sanitize(((Hashtable)item["Request"])["Method"]))
                        .Append(" ").Append(Sanitize(((Hashtable)item["Request"])["Resource"])).Append(" ").Append(Sanitize(((Hashtable)item["Request"])["Query"]))
                        .Append(" ").Append(Sanitize(((Hashtable)item["Response"])["StatusCode"])).Append(" \"").Append(Sanitize(((Hashtable)item["Request"])["Agent"])).Append("\"")
                        .ToString();

                case "common":
                    return sb.Append(Sanitize(item["Host"])).Append(" ").Append(Sanitize(item["RfcUserIdentity"])).Append(" ").Append(Sanitize(item["User"])).Append(" [")
                        .Append(Regex.Replace(((DateTime)item["Date"]).ToString("dd/MMM/yyyy:HH:mm:ss zzz"), @"([+-]\d{2}):(\d{2})", "$1$2")).Append("] \"")
                        .Append(Sanitize(((Hashtable)item["Request"])["Method"])).Append(" ").Append(Sanitize(((Hashtable)item["Request"])["Resource"])).Append(" ")
                        .Append(Sanitize(((Hashtable)item["Request"])["Protocol"])).Append("\" ").Append(Sanitize(((Hashtable)item["Response"])["StatusCode"]))
                        .Append(" ").Append(Sanitize(((Hashtable)item["Response"])["Size"])).ToString();

                case "json":
                    return sb.Append("{\"time\": \"").Append(((DateTime)item["Date"]).ToString("yyyy-MM-ddTHH:mm:ssK")).Append("\",\"remote_ip\": \"")
                        .Append(Sanitize(item["Host"])).Append("\",\"user\": \"").Append(Sanitize(item["User"])).Append("\",\"method\": \"")
                        .Append(Sanitize(((Hashtable)item["Request"])["Method"])).Append("\",\"uri\": \"").Append(Sanitize(((Hashtable)item["Request"])["Resource"]))
                        .Append("\",\"query\": \"").Append(Sanitize(((Hashtable)item["Request"])["Query"])).Append("\",\"status\": ")
                        .Append(Sanitize(((Hashtable)item["Response"])["StatusCode"])).Append(",\"response_size\": ")
                        .Append(Sanitize(((Hashtable)item["Response"])["Size"])).Append(",\"user_agent\": \"").Append(Sanitize(((Hashtable)item["Request"])["Agent"]))
                        .Append("\"}").ToString();

                // Combined is the default format
                default:
                    return sb.Append(Sanitize(item["Host"])).Append(" ").Append(Sanitize(item["RfcUserIdentity"])).Append(" ").Append(Sanitize(item["User"])).Append(" [")
                        .Append(Regex.Replace(((DateTime)item["Date"]).ToString("dd/MMM/yyyy:HH:mm:ss zzz"), @"([+-]\d{2}):(\d{2})", "$1$2")).Append("] \"")
                        .Append(Sanitize(((Hashtable)item["Request"])["Method"])).Append(" ").Append(Sanitize(((Hashtable)item["Request"])["Resource"])).Append(" ")
                        .Append(Sanitize(((Hashtable)item["Request"])["Protocol"])).Append("\" ").Append(Sanitize(((Hashtable)item["Response"])["StatusCode"]))
                        .Append(" ").Append(Sanitize(((Hashtable)item["Response"])["Size"])).Append(" \"")
                        .Append(Sanitize(((Hashtable)item["Request"])["Referrer"])).Append("\" \"").Append(Sanitize(((Hashtable)item["Request"])["Agent"])).Append("\"")
                        .ToString();
            }
        }


        public static object GeneralLog(Hashtable item, Hashtable options)
        {
            // Do nothing if the error level isn't present in the options' Levels array
            if (options.ContainsKey("Levels") && !((IList)options["Levels"]).Contains(item["Level"]))
            {
                return null;
            }

            // Just return the item if Raw is set
            if (options.ContainsKey("Raw") && (bool)options["Raw"])
            {
                return item;
            }

            // Optimized concatenation using StringBuilder
            StringBuilder sb = new StringBuilder();
            return sb.Append("[").Append(((DateTime)item["Date"]).ToString(options["DataFormat"].ToString())).Append("] ")
                     .Append(item["Level"]).Append(" ").Append(item["Tag"]).Append(" ").Append(item["ThreadId"]).Append(" ").Append(item["Message"])
                     .ToString();
        }

    }

}
