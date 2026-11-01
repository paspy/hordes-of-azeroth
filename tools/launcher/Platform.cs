using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Formats.Tar;

namespace HordesOfAzeroth.Launcher
{
    static class Platform
    {
        const UnixFileMode Executable = UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute
            | UnixFileMode.GroupRead | UnixFileMode.GroupExecute | UnixFileMode.OtherRead | UnixFileMode.OtherExecute;
        static readonly byte[][] ProgramMagics =
        {
            new byte[] { 0x7F, (byte)'E', (byte)'L', (byte)'F' },
            new byte[] { 0xCF, 0xFA, 0xED, 0xFE },
            new byte[] { 0xCE, 0xFA, 0xED, 0xFE },
            new byte[] { 0xCA, 0xFE, 0xBA, 0xBE },
        };

        public static bool IsWindows => OperatingSystem.IsWindows();

        public static bool IsMacOS => OperatingSystem.IsMacOS();

        public static bool HasTray => IsWindows;

        public static string ManifestName => IsWindows ? "manifest.json" : IsMacOS ? "manifest-macos.json" : "manifest-linux.json";

        public static string SystemName => IsWindows ? "Windows" : IsMacOS ? "macOS" : "Linux";

        public static StringComparison PathComparison => IsWindows || IsMacOS ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

        public static string Exe(string name) => IsWindows ? name + ".exe" : name;

        public static void OpenFolder(string path) => Open(path);

        public static void OpenUrl(string url) => Open(url);

        public static void ShowFile(string file)
        {
            if (IsWindows)
                Process.Start(new ProcessStartInfo("explorer.exe", "/select,\"" + file + "\"") { UseShellExecute = true });
            else if (IsMacOS)
                Process.Start(new ProcessStartInfo("open") { ArgumentList = { "-R", file }, UseShellExecute = false });
            else
                Open(Path.GetDirectoryName(file));
        }

        static void Open(string target)
        {
            if (IsWindows)
                Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
            else
                Process.Start(new ProcessStartInfo(IsMacOS ? "open" : "xdg-open") { ArgumentList = { target }, UseShellExecute = false });
        }

        public static void MarkExecutableIfProgram(string file)
        {
            if (IsWindows || !IsProgram(file))
                return;
            File.SetUnixFileMode(file, Executable);
        }

        static bool IsProgram(string file)
        {
            byte[] head = new byte[4];
            using (FileStream stream = File.OpenRead(file))
                if (stream.Read(head, 0, head.Length) < head.Length)
                    return false;
            foreach (byte[] magic in ProgramMagics)
                if (head.AsSpan().SequenceEqual(magic))
                    return true;
            return false;
        }

        public static bool IsTarball(string file) => file.EndsWith(".tar.gz", StringComparison.OrdinalIgnoreCase) || file.EndsWith(".tgz", StringComparison.OrdinalIgnoreCase);

        public static void ExtractTarball(string tarball, string targetDir, bool stripTopFolder)
        {
            string root = Path.GetFullPath(targetDir).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            using (FileStream file = File.OpenRead(tarball))
            using (GZipStream gzip = new GZipStream(file, CompressionMode.Decompress))
            using (TarReader reader = new TarReader(gzip))
            {
                TarEntry entry;
                while ((entry = reader.GetNextEntry()) != null)
                {
                    string relative = entry.Name.TrimStart('.', '/');
                    if (stripTopFolder)
                    {
                        int slash = relative.IndexOf('/');
                        if (slash < 0)
                            continue;
                        relative = relative.Substring(slash + 1);
                    }
                    if (relative.Length == 0)
                        continue;
                    string target = Path.GetFullPath(Path.Combine(root, relative));
                    if (!target.StartsWith(root, StringComparison.Ordinal))
                        throw new InvalidDataException(Loc.T("{0} contains a path outside the game folder.", Path.GetFileName(tarball)));
                    switch (entry.EntryType)
                    {
                        case TarEntryType.Directory:
                            Directory.CreateDirectory(target);
                            break;
                        case TarEntryType.SymbolicLink:
                            Directory.CreateDirectory(Path.GetDirectoryName(target));
                            if (File.Exists(target) || Directory.Exists(target))
                                File.Delete(target);
                            File.CreateSymbolicLink(target, entry.LinkName);
                            break;
                        case TarEntryType.RegularFile:
                        case TarEntryType.V7RegularFile:
                            Directory.CreateDirectory(Path.GetDirectoryName(target));
                            entry.ExtractToFile(target, true);
                            break;
                    }
                }
            }
        }
    }
}
