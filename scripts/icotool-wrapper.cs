// icotool-wrapper.cs
// Minimal icotool replacement for ECMAddAppIcon on Windows.
// Translates: icotool --create -o output.ico input1.png input2.png ...
//         to: magick input1.png input2.png output.ico
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

class IcoTool {
    static int Main(string[] args) {
        string output = null;
        var inputs = new List<string>();

        for (int i = 0; i < args.Length; i++) {
            if (args[i] == "--create" || args[i] == "-r" || args[i] == "--raw") continue;
            if (args[i] == "-o" && i + 1 < args.Length) { output = args[++i]; continue; }
            if (!args[i].StartsWith("-")) inputs.Add(args[i]);
        }

        if (output == null || inputs.Count == 0) {
            Console.Error.WriteLine("icotool-wrapper: missing arguments");
            return 1;
        }

        // Build magick command: magick input1.png input2.png output.ico
        var magickArgs = new System.Text.StringBuilder();
        foreach (var f in inputs) magickArgs.Append("\"").Append(f).Append("\" ");
        magickArgs.Append("\"").Append(output).Append("\"");

        var psi = new ProcessStartInfo {
            FileName = "magick",
            Arguments = magickArgs.ToString(),
            UseShellExecute = false,
            RedirectStandardError = true
        };

        try {
            var p = Process.Start(psi);
            string err = p.StandardError.ReadToEnd();
            p.WaitForExit();
            if (p.ExitCode != 0 && !string.IsNullOrEmpty(err))
                Console.Error.WriteLine("magick: " + err);
            return p.ExitCode;
        } catch (Exception ex) {
            Console.Error.WriteLine("icotool-wrapper: " + ex.Message);
            return 1;
        }
    }
}
