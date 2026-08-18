using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Windows.EventTracing;
using Microsoft.Windows.EventTracing.Cpu;

static string RequireValue(string[] arguments, ref int index, string option)
{
    index++;
    if (index >= arguments.Length)
    {
        throw new ArgumentException($"{option} requires a value.");
    }

    return arguments[index];
}

static Regex WildcardRegex(string pattern)
{
    string expression = "^" + Regex.Escape(pattern)
        .Replace("\\*", ".*", StringComparison.Ordinal)
        .Replace("\\?", ".", StringComparison.Ordinal) + "$";
    return new Regex(expression, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
}

static string CleanSegment(string? value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return "[unknown]";
    }

    return value.Replace(';', ':').Replace('\r', ' ').Replace('\n', ' ').Trim();
}

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: NativeCpuStacks <trace.etl> <output.folded> [--pid N] [--process PATTERN] [--start SECONDS --end SECONDS]");
    return 2;
}

string tracePath = Path.GetFullPath(args[0]);
string outputPath = Path.GetFullPath(args[1]);
var processIds = new HashSet<int>();
var processPatterns = new List<Regex>();
decimal? startSeconds = null;
decimal? endSeconds = null;

for (int index = 2; index < args.Length; index++)
{
    switch (args[index])
    {
        case "--pid":
            processIds.Add(int.Parse(RequireValue(args, ref index, "--pid"), CultureInfo.InvariantCulture));
            break;
        case "--process":
            processPatterns.Add(WildcardRegex(RequireValue(args, ref index, "--process")));
            break;
        case "--start":
            startSeconds = decimal.Parse(RequireValue(args, ref index, "--start"), CultureInfo.InvariantCulture);
            break;
        case "--end":
            endSeconds = decimal.Parse(RequireValue(args, ref index, "--end"), CultureInfo.InvariantCulture);
            break;
        default:
            throw new ArgumentException($"Unknown option: {args[index]}");
    }
}

if (startSeconds.HasValue != endSeconds.HasValue)
{
    throw new ArgumentException("--start and --end must be specified together.");
}

if (startSeconds.HasValue && endSeconds <= startSeconds)
{
    throw new ArgumentException("--end must be greater than --start.");
}

bool IsSelected(int id, string name)
{
    if (processIds.Count == 0 && processPatterns.Count == 0)
    {
        return true;
    }

    string baseName = Path.GetFileNameWithoutExtension(name);
    return processIds.Contains(id) || processPatterns.Any(pattern => pattern.IsMatch(name) || pattern.IsMatch(baseName));
}

using ITraceProcessor trace = TraceProcessor.Create(tracePath);
var cpuSampling = trace.UseCpuSamplingData();
trace.Process();

var stacks = new Dictionary<string, long>(StringComparer.Ordinal);
long selectedSamples = 0;
long samplesWithoutStacks = 0;

foreach (var sample in cpuSampling.Result.Samples)
{
    if (startSeconds.HasValue && (sample.Timestamp.TotalSeconds < startSeconds || sample.Timestamp.TotalSeconds > endSeconds))
    {
        continue;
    }

    string processName = sample.Process?.ImageName ?? "[unknown]";
    int processId = sample.Process?.Id ?? sample.Thread?.ProcessId ?? -1;
    if (!IsSelected(processId, processName))
    {
        continue;
    }

    selectedSamples++;
    if (sample.Stack is null || sample.Stack.Frames.Count == 0)
    {
        samplesWithoutStacks++;
        continue;
    }

    var segments = new List<string> { $"{CleanSegment(processName)} ({processId})" };
    string? previousModule = null;
    for (int frameIndex = sample.Stack.Frames.Count - 1; frameIndex >= 0; frameIndex--)
    {
        string module = CleanSegment(sample.Stack.Frames[frameIndex].Image?.FileName);
        if (!string.Equals(module, previousModule, StringComparison.OrdinalIgnoreCase))
        {
            segments.Add(module);
            previousModule = module;
        }
    }

    string key = string.Join(';', segments);
    stacks[key] = stacks.GetValueOrDefault(key) + 1;
}

Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
using (var writer = new StreamWriter(outputPath, false, new UTF8Encoding(false)))
{
    foreach (var entry in stacks.OrderByDescending(entry => entry.Value).ThenBy(entry => entry.Key, StringComparer.Ordinal))
    {
        writer.WriteLine($"{entry.Key} {entry.Value.ToString(CultureInfo.InvariantCulture)}");
    }
}

Console.WriteLine(JsonSerializer.Serialize(new
{
    Trace = tracePath,
    Folded = outputPath,
    SelectedSamples = selectedSamples,
    SamplesWithoutStacks = samplesWithoutStacks,
    UniqueStacks = stacks.Count,
}));

return stacks.Count == 0 ? 3 : 0;
