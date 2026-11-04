using System;
using System.IO;

// 自测用的 adb/fastboot 假件：只打印，绝不碰 USB 也绝不碰手机。
// 编两份同名不同扩展名的产物（adb.exe / fastboot.exe），靠 argv[0] 的文件名分行为。
class DevShim
{
    static void Main(string[] args)
    {
        string me = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        string cmd = args.Length > 0 ? args[0] : "";
        string rest = args.Length > 1 ? string.Join(" ", args, 1, args.Length - 1) : "";

        if (me == "adb")
        {
            if (cmd == "devices")
            {
                Console.WriteLine("List of devices attached");
                Console.WriteLine("a7d186f4\tdevice");
            }
            else Console.WriteLine("(shim adb) " + cmd + " " + rest);
        }
        else
        {
            if (cmd == "devices") Console.WriteLine("a7d186f4 fastboot");
            else if (cmd == "boot")
            {
                Console.WriteLine("(shim fastboot) boot " + rest);
                Console.WriteLine("OKAY [  0.001s]");
                Console.WriteLine("finished. total time: 0.001s");
            }
            else Console.WriteLine("(shim fastboot) " + cmd + " " + rest);
        }
    }
}
