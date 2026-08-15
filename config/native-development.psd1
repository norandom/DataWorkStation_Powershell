@{
    SchemaVersion = 1
    Msvc = @{
        PackageId = 'Microsoft.VisualStudio.2022.BuildTools'
        RequiredComponents = @(
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
            'Microsoft.VisualStudio.Component.Windows11SDK.26100'
        )
        ExcludedComponentPatterns = @('ARM', 'ATL', 'MFC', 'CLI', 'UWP', 'IDE')
        HostArchitecture = 'amd64'
        TargetArchitecture = 'amd64'
    }
    Packages = @{
        CMake = 'Kitware.CMake'
        Ninja = 'Ninja-build.Ninja'
        Rustup = 'Rustlang.Rustup'
        Java = 'Microsoft.OpenJDK.21'
    }
    Rust = @{
        Profile = 'default'
        Toolchain = 'stable-x86_64-pc-windows-msvc'
    }
    Java = @{
        MajorVersion = 21
        Commands = @('java.exe', 'javac.exe', 'jar.exe', 'jshell.exe')
    }
    Environment = @{
        CC = 'cl.exe'
        CXX = 'cl.exe'
        CMakeGenerator = 'Ninja'
        CargoHome = '.cargo'
        RustupHome = '.rustup'
    }
}
