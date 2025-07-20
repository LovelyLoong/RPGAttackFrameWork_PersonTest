# Project Structure

## Root Directory
```
├── .git/                    # Git version control
├── .gitignore              # Git ignore rules
├── .kiro/                  # Kiro AI assistant configuration
├── LICENSE                 # MIT license file
├── README.md               # Project documentation (Chinese)
└── RPG Game Frame Work/    # Main Unity project directory
```

## Unity Project Structure (`RPG Game Frame Work/`)

### Core Project Files
```
├── RPG Game Frame Work.sln           # Visual Studio solution
├── *.csproj                         # C# project files
├── Assembly-CSharp.csproj           # Main game assembly
├── Assembly-CSharp-Editor.csproj    # Editor assembly
├── UnityGameFramework.Runtime.csproj # Runtime framework
└── UnityGameFramework.Editor.csproj  # Editor framework
```

### Unity Directories
```
├── Assets/                  # Unity assets and scripts
│   ├── Data/               # Generated data files
│   │   ├── Gen/           # Auto-generated code
│   │   └── GenerateData/  # Generated data assets
│   ├── LubanLib/          # Luban serialization library
│   ├── Scenes/            # Unity scene files
│   ├── Scripts/           # C# game scripts
│   ├── Settings/          # Render pipeline and project settings
│   └── TutorialInfo/      # Unity tutorial assets
├── Library/               # Unity cache (auto-generated)
├── Logs/                  # Unity logs
├── Packages/              # Unity package manager
├── ProjectSettings/       # Unity project configuration
├── Temp/                  # Temporary Unity files
└── UserSettings/          # User-specific Unity settings
```

### Data Management
```
├── DataTables/            # Data configuration system
│   ├── Datas/            # Excel data source files
│   │   ├── __beans__.xlsx      # Data structure definitions
│   │   ├── __enums__.xlsx      # Enumeration definitions
│   │   ├── __tables__.xlsx     # Table configurations
│   │   └── ConditionSystem/    # Condition system data
│   ├── Defines/          # XML schema definitions
│   ├── output/           # Generated output files
│   ├── gen_client.bat    # Windows data generation script
│   ├── gen.bat          # General generation script
│   ├── gen.sh           # Unix/Linux generation script
│   └── luban.conf       # Luban configuration
```

### Development Tools
```
└── Tools/
    └── Luban/            # Luban data generation tool
        ├── Luban.exe     # Main executable
        ├── Templates/    # Code generation templates
        └── *.dll         # Supporting libraries
```

## Naming Conventions
- **Folders**: PascalCase for Unity folders, lowercase for system folders
- **Files**: PascalCase for C# files, lowercase with extensions for config files
- **Classes**: PascalCase following C# conventions
- **Data Tables**: Excel files use double underscore prefix for system files

## Key Integration Points
- **Data Flow**: Excel → Luban → Generated C# → Unity Assets
- **Code Organization**: Separate assemblies for runtime vs editor code
- **Asset Management**: Centralized in Assets/ with logical subfolder organization