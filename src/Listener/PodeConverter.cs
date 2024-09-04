#if !NETSTANDARD2_0

using System;
using System.Collections;
using System.Collections.Specialized;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;

namespace Pode
{
    public static class PodeConverter
    {
        public static string ToYaml(object inputObject, int depth = 10, int nestingLevel = 0, bool noNewLine = false)
        {
            if (depth < nestingLevel)
            {
                return string.Empty;
            }

            if (inputObject == null)
            {
                return inputObject is Array ? "[]" : string.Empty;
            }

            string padding = new string(' ', nestingLevel * 2);
            string type = inputObject.GetType().Name;

            if (inputObject is Array)
            {
                type = inputObject.GetType().BaseType.Name;
            }

            if (type != "String")
            {
                if (inputObject is OrderedDictionary)
                {
                    type = "ordereddictionary";
                }
                else if (inputObject is IList)
                {
                    type = "array";
                }
                else if (inputObject is Hashtable)
                {
                    type = "hashtable";
                }
            }

            StringBuilder output = new StringBuilder();
            switch (type.ToLower())
            {
                case "string":
                    string stringValue = inputObject.ToString();
                    if ((stringValue.Contains("\r\n") || stringValue.Length > 80) && !stringValue.StartsWith("http"))
                    {
                        StringBuilder multiline = new StringBuilder("|" + Environment.NewLine);
                        string[] items = stringValue.Split(new[] { "\n" }, StringSplitOptions.None);
                        foreach (string item in items)
                        {
                            string workingString = item.Replace("\r", "");
                            int length = workingString.Length;
                            int index = 0;
                            int wrap = 80;

                            while (index < length)
                            {
                                int breakpoint = wrap;
                                bool linebreak = false;

                                if ((length - index) > wrap)
                                {
                                    int lastSpaceIndex = workingString.LastIndexOf(' ', index + wrap, wrap);
                                    if (lastSpaceIndex != -1)
                                    {
                                        breakpoint = lastSpaceIndex - index;
                                    }
                                    else
                                    {
                                        linebreak = true;
                                        breakpoint--;
                                    }
                                }
                                else
                                {
                                    breakpoint = length - index;
                                }

                                multiline.Append(padding).Append(workingString.Substring(index, breakpoint).Trim());
                                if (linebreak)
                                {
                                    multiline.Append('\\');
                                }

                                index += breakpoint;
                                if (index < length)
                                {
                                    multiline.Append(Environment.NewLine);
                                }
                            }

                            multiline.Append(Environment.NewLine);
                        }

                        output.Append(multiline.ToString().TrimEnd());
                    }
                    else
                    {
                        if (stringValue.StartsWith("#") || stringValue.StartsWith("[") || stringValue.StartsWith("]") || stringValue.StartsWith("@") || stringValue.StartsWith("{") || stringValue.StartsWith("}") || stringValue.StartsWith("!") || stringValue.StartsWith("*"))
                        {
                            output.AppendFormat("'{0}'", stringValue.Replace("'", "''"));
                        }
                        else
                        {
                            output.Append(stringValue);
                        }
                    }
                    break;

                case "hashtable":
                case "ordereddictionary":
                    if (inputObject is IDictionary dict && dict.Count > 0)
                    {
                        int index = 0;
                        StringBuilder stringBuilder = new StringBuilder();
                        foreach (DictionaryEntry item in dict)
                        {
                            string newPadding = noNewLine && index++ == 0 ? string.Empty : Environment.NewLine + padding;
                            stringBuilder.Append(newPadding).Append(item.Key).Append(": ");
                            if (item.Value is ValueType)
                            {
                                if (item.Value is bool)
                                {
                                    stringBuilder.Append(item.Value.ToString().ToLower());
                                }
                                else
                                {
                                    stringBuilder.Append(item.Value);
                                }
                            }
                            else
                            {
                                int increment = item.Value is string ? 2 : 1;
                                stringBuilder.Append(ToYaml(item.Value, depth, nestingLevel + increment));
                            }
                        }
                        output.Append(stringBuilder.ToString());
                    }
                    else
                    {
                        output.Append("{}");
                    }
                    break;

                case "pscustomobject":
                    if (inputObject is PSObject psObject && psObject.Properties.Any())
                    {
                        int index = 0;
                        StringBuilder stringBuilder = new StringBuilder();
                        foreach (PSPropertyInfo item in psObject.Properties)
                        {
                            string newPadding = noNewLine && index++ == 0 ? string.Empty : Environment.NewLine + padding;
                            stringBuilder.Append(newPadding).Append(item.Name).Append(": ");
                            if (item.Value is ValueType)
                            {
                                if (item.Value is bool)
                                {
                                    stringBuilder.Append(item.Value.ToString().ToLower());
                                }
                                else
                                {
                                    stringBuilder.Append(item.Value);
                                }
                            }
                            else
                            {
                                int increment = item.Value is string ? 2 : 1;
                                stringBuilder.Append(ToYaml(item.Value, depth, nestingLevel + increment));
                            }
                        }
                        output.Append(stringBuilder.ToString());
                    }
                    else
                    {
                        output.Append("{}");
                    }
                    break;

                case "array":
                    IList list = inputObject as IList;
                    if (list != null && list.Count == 0)
                    {
                        output.Append("[]");
                    }
                    else
                    {
                        StringBuilder arrayStringBuilder = new StringBuilder();
                        int arrayIndex = 0;
                        foreach (object item in list)
                        {
                            string newPadding = noNewLine && arrayIndex++ == 0 ? string.Empty : Environment.NewLine + padding;
                            arrayStringBuilder.Append(newPadding).Append("- ").Append(ToYaml(item, depth, nestingLevel + 1, true).Trim('\''));
                        }
                        output.Append(arrayStringBuilder.ToString());
                    }
                    break;

                default:
                    output.AppendFormat("'{0}'", inputObject);
                    break;
            }

            return output.ToString();
        }


        public static OrderedDictionary FromYaml(string inputObject)
        {
            // Split the YAML input into lines
            string[] lines = inputObject.Split(new[] { "\n" }, StringSplitOptions.None);
            // Initialize the main hashtable as an ordered hashtable
            var hashtable = new OrderedDictionary();
            // Stacks to keep track of current hashtable and indentation levels
            var stack = new Stack();
            var indentStack = new Stack();
            stack.Push(hashtable);
            indentStack.Push(-1);

            // Regex patterns for matching lines
            var keyValuePattern = new Regex(@"^(\s*)([^:]+):\s*(.*)$");
            var arrayPattern = new Regex(@"^\[(.*)\]$");
            var multilinePattern = new Regex(@"^\s+(.*)$");
            var listItemPattern = new Regex(@"^\s*-\s*(.*)$");

            // Variables to keep track of current key and hashtable
            OrderedDictionary current = hashtable;
            string currentKey = null;

            // Iterate over each line of the YAML input
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                Match match = keyValuePattern.Match(line);
                if (match.Success)
                {
                    int indent = match.Groups[1].Length; // Indentation level
                    string key = match.Groups[2].Value.Trim(); // Key
                    string value = match.Groups[3].Value.Trim(); // Value

                    // Pop the stack if the current indentation level is less than or equal to the previous level
                    while ((int)indentStack.Peek() >= indent)
                    {
                        indentStack.Pop();
                        stack.Pop();
                    }

                    // Peek the current hashtable from the stack
                    current = (OrderedDictionary)stack.Peek();
                    currentKey = key;

                    // If value is empty, create a new nested ordered hashtable
                    if (string.IsNullOrEmpty(value))
                    {
                        var newDict = new OrderedDictionary();
                        current[key] = newDict;
                        stack.Push(newDict);
                        indentStack.Push(indent);
                    }
                    // Handle inline arrays
                    else if (arrayPattern.IsMatch(value))
                    {
                        current[key] = arrayPattern.Match(value).Groups[1].Value.Split(new[] { ", " }, StringSplitOptions.None);
                    }
                    // Handle multiline strings
                    else if (value == "|")
                    {
                        value = string.Empty;
                        while (++i < lines.Length && multilinePattern.IsMatch(lines[i]))
                        {
                            value += multilinePattern.Match(lines[i]).Groups[1].Value + "\n";
                        }
                        i--;
                        current[key] = value.TrimEnd();
                    }
                    // Convert and assign the value
                    else
                    {
                        current[key] = ConvertPodeStringToType(value);
                    }
                }
                // Handle list items
                else if (listItemPattern.IsMatch(line))
                {
                    string value = listItemPattern.Match(line).Groups[1].Value.Trim();
                    if (!(current[currentKey] is ArrayList list))
                    {
                        list = new ArrayList();
                        current[currentKey] = list;
                    }
                    list.Add(ConvertPodeStringToType(value));
                }
            }

            return hashtable;
        }


        private static object ConvertPodeStringToType(string value)
        {
            if (bool.TryParse(value, out bool boolResult)) return boolResult;
            if (int.TryParse(value, out int intResult)) return intResult;
            if (double.TryParse(value, out double doubleResult)) return doubleResult;
            if (DateTime.TryParse(value, out DateTime dateResult)) return dateResult;
            return value;
        }
    }



}
#endif