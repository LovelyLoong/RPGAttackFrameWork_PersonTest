# Technology Stack

## Core Technologies
- **Unity Engine**: Game development platform
- **C#**: Primary programming language
- **Universal Render Pipeline (URP)**: Unity's rendering pipeline
- **Unity Input System**: Modern input handling

## Data Management
- **Luban**: Data table generation and management tool
- **Excel/XLSX**: Data source files for configuration
- **Binary serialization**: Runtime data format

## Build System
- **Unity Editor**: Primary development environment
- **Visual Studio Solution**: C# project management
- **MSBuild**: Compilation system

## Project Structure
- **UnityGameFramework.Runtime**: Core runtime framework
- **UnityGameFramework.Editor**: Editor-time tools and utilities
- **Assembly-CSharp**: Main game logic
- **Assembly-CSharp-Editor**: Editor extensions

## Common Commands

### Data Table Generation
```bash
# Generate data tables (Windows)
cd "RPG Game Frame Work/DataTables"
gen_client.bat

# Generate data tables (Unix/Linux)
./gen.sh
```

### Unity Build
- Open project in Unity Editor
- Use Unity's built-in build system
- Target platforms: PC, Mobile (configured renderers available)

## Development Tools
- **Luban Tool**: Located in `Tools/Luban/` directory
- **Data Tables**: Configuration in `DataTables/` directory
- **Input Actions**: Configured in `InputSystem_Actions.inputactions`