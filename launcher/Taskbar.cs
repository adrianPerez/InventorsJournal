// Gives Inventor's Journal its own taskbar identity.
//
// Windows groups and pins taskbar buttons by an "AppUserModelID". Edge gives
// its --app windows an ID that Windows treats as Edge, so pinning the running
// window showed the Edge icon. Here we stamp the same custom ID on both the
// shortcut and the journal window, and tell Windows how to relaunch it
// (command, name, icon) when it is pinned.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace InventorsJournal
{
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey
    {
        public Guid fmtid;
        public uint pid;
    }

    // Only the VT_LPWSTR form is used. Sized for x64 (24 bytes); larger than
    // needed on x86, which is harmless because it is passed by reference.
    [StructLayout(LayoutKind.Explicit, Size = 24)]
    public struct PropVariant
    {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pointer;
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore
    {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetAt(uint index, out PropertyKey key);
        [PreserveSig] int GetValue(ref PropertyKey key, IntPtr value);
        [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant value);
        [PreserveSig] int Commit();
    }

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public class ShellLink { }

    public static class Taskbar
    {
        // PKEY_AppUserModel_* (propkey.h)
        static readonly Guid AppUserModel = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        const uint RelaunchCommand = 2;
        const uint RelaunchIconResource = 3;
        const uint RelaunchDisplayNameResource = 4;
        const uint ID = 5;
        const ushort VT_LPWSTR = 31;
        const int STGM_READWRITE = 2;

        delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int maxCount);
        [DllImport("shell32.dll")]
        static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

        static readonly HashSet<IntPtr> tagged = new HashSet<IntPtr>();

        static void SetString(IPropertyStore store, uint pid, string value)
        {
            var key = new PropertyKey { fmtid = AppUserModel, pid = pid };
            var pv = new PropVariant { vt = VT_LPWSTR, pointer = Marshal.StringToCoTaskMemUni(value) };
            try
            {
                Marshal.ThrowExceptionForHR(store.SetValue(ref key, ref pv));
                Marshal.ThrowExceptionForHR(store.Commit());
            }
            finally
            {
                Marshal.FreeCoTaskMem(pv.pointer);
            }
        }

        // Writes the AppUserModelID into an existing .lnk shortcut.
        public static void SetShortcutAppId(string shortcutPath, string appId)
        {
            object link = new ShellLink();
            try
            {
                ((IPersistFile)link).Load(shortcutPath, STGM_READWRITE);
                SetString((IPropertyStore)link, ID, appId);
                ((IPersistFile)link).Save(shortcutPath, true);
            }
            finally
            {
                Marshal.ReleaseComObject(link);
            }
        }

        // Finds visible Chromium/Edge windows titled exactly `title` and gives
        // each one the journal's identity. Returns how many were newly tagged.
        public static int TagWindows(string title, string appId, string relaunchCommand, string displayName, string iconResource)
        {
            var found = new List<IntPtr>();
            EnumWindows((hwnd, lParam) =>
            {
                if (tagged.Contains(hwnd) || !IsWindowVisible(hwnd)) return true;
                var text = new StringBuilder(512);
                GetWindowText(hwnd, text, text.Capacity);
                if (text.ToString() != title) return true;
                var cls = new StringBuilder(256);
                GetClassName(hwnd, cls, cls.Capacity);
                if (cls.ToString().StartsWith("Chrome_WidgetWin")) found.Add(hwnd);
                return true;
            }, IntPtr.Zero);

            int count = 0;
            foreach (var hwnd in found)
            {
                var iid = typeof(IPropertyStore).GUID;
                IPropertyStore store;
                if (SHGetPropertyStoreForWindow(hwnd, ref iid, out store) != 0 || store == null) continue;
                try
                {
                    // Relaunch details first, so they are in place when the ID changes.
                    SetString(store, RelaunchCommand, relaunchCommand);
                    SetString(store, RelaunchIconResource, iconResource);
                    SetString(store, RelaunchDisplayNameResource, displayName);
                    SetString(store, ID, appId);
                    tagged.Add(hwnd);
                    count++;
                }
                catch (Exception)
                {
                    // Leave the window as Edge left it; the journal still works.
                }
                finally
                {
                    Marshal.ReleaseComObject(store);
                }
            }
            return count;
        }
    }
}
