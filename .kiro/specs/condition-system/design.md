# 条件系统设计文档

## 概述

条件系统是一个基于GF框架的数据驱动条件判断模块，通过配置化的方式定义各种游戏逻辑条件，并在运行时提供高效的条件状态管理服务。系统采用事件驱动架构，通过GameDataBlackboard监听数据变化，触发条件重新评估，并通知相关监听者。

## 架构

### 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    条件系统架构                              │
├─────────────────────────────────────────────────────────────┤
│  业务层 (Business Layer)                                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐       │
│  │ 成就系统     │ │ 任务系统     │ │ 其他业务模块     │       │
│  └─────────────┘ └─────────────┘ └─────────────────┘       │
│           │              │                │                │
│           └──────────────┼────────────────┘                │
│                          │                                 │
├─────────────────────────────────────────────────────────────┤
│  管理层 (Management Layer)                                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              ConditionManager                           ││
│  │              (GF Component)                             ││
│  │  ┌─────────────────┐  ┌─────────────────────────────┐   ││
│  │  │ GetConditionState│  │ AddConditionListener        │   ││
│  │  │ (int id)        │  │ (int id, Action<ConditionState>)││
│  │  └─────────────────┘  └─────────────────────────────┘   ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Dictionary<int, HashSet<Action<ConditionState>>>    │││
│  │  │ _conditionListeners                                 │││
│  │  └─────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────┘│
│                          │                                 │
├─────────────────────────────────────────────────────────────┤
│  数据监听层 (Data Listening Layer)                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              GameDataBlackboard                         ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Dictionary<GlobalDataKey, HashSet<int>>             │││
│  │  │ _dataKeyToConditions                                │││
│  │  └─────────────────────────────────────────────────────┘││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Dictionary<int, ConditionState>                     │││
│  │  │ _conditionStates                                    │││
│  │  └─────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────┘│
│                          │                                 │
├─────────────────────────────────────────────────────────────┤
│  存储层 (Storage Layer)                                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              GF Setting Component                       ││
│  │              (本地存储)                                  ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  数据层 (Data Layer)                                        │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ cfg.Condition   │  │ GlobalDataKey   │                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

### 数据流向

```
游戏机制产出数据 → GameDataBlackboard → 条件重新评估 → ConditionManager → 业务模块
     ↓                    ↓                    ↓               ↓
   数据变化事件        监听数据变化          状态变化通知      响应条件变化
```

## 组件和接口

### 1. 数据层组件

#### cfg.ConditionSystem.Condition (已存在)
配置数据类，包含条件的基础信息：
- ConfigId: 条件唯一标识
- Type: 条件类型枚举
- Target: 条件目标值
- Comparison: 比较操作符
- LogicalOperator: 逻辑操作符
- DataKey: 全局数据键
- IsPermanent: 是否为永久条件
- SubConditions: 子条件列表

#### ConditionState (可序列化条件状态)
条件状态类，支持对象池复用：

```csharp
[System.Serializable]
public class ConditionState : IReference
{
    public int ConditionId;
    public bool IsCompleted;
    public float Progress;  // 0.0 - 1.0
    public object CurrentValue;
    public long LastUpdateTicks;  // DateTime.Ticks for serialization
    public Dictionary<string, object> ExtendedData;
    
    public DateTime LastUpdateTime 
    { 
        get => new DateTime(LastUpdateTicks);
        set => LastUpdateTicks = value.Ticks;
    }
    
    public ConditionState()
    {
        ExtendedData = new Dictionary<string, object>();
    }
    
    public void Initialize(int conditionId)
    {
        ConditionId = conditionId;
        IsCompleted = false;
        Progress = 0.0f;
        LastUpdateTime = DateTime.Now;
        CurrentValue = null;
        ExtendedData.Clear();
    }
    
    // IReference implementation for object pool
    public void Clear()
    {
        ConditionId = 0;
        IsCompleted = false;
        Progress = 0.0f;
        CurrentValue = null;
        LastUpdateTicks = 0;
        ExtendedData.Clear();
    }
}

public enum ConditionStability
{
    Volatile = 0,    // 易变的，每次数据变化都重新计算（如钻石数量、HP值）
    Permanent = 1    // 永久的，一旦完成永不重置（如成就、通关记录）
}

public enum ConditionGroup
{
    Global = 0,        // 全局组，优先级0
    Achievement = 1,   // 成就组，优先级1
    Task = 2,         // 任务组，优先级2
    Battle = 3,       // 战斗组，优先级3
    Social = 4,       // 社交组，优先级4
}
```

### 2. 管理层组件

#### ConditionManager (基于GF框架组件)
条件系统的核心管理器，继承自GF框架的GameFrameworkComponent：

```csharp
public sealed class ConditionManager : GameFrameworkComponent
{
    // 监听者存储（使用弱引用避免内存泄漏）
    private Dictionary<int, List<WeakReference<Action<ConditionState>>>> _conditionListeners;
    
    // 条件状态缓存（运行时懒加载）
    private Dictionary<int, ConditionState> _conditionStates;
    
    // 条件配置数据缓存（按优先级排序）
    private Dictionary<int, cfg.ConditionSystem.Condition> _conditionConfigs;
    private Dictionary<ConditionGroup, List<int>> _groupToConditions;
    
    // 数据键到条件的映射
    private Dictionary<GlobalDataKey, HashSet<int>> _dataKeyToConditions;
    
    // 已完成的永久条件ID集合（本地存储）
    private HashSet<int> _completedPermanentConditions;
    
    // 延迟处理队列
    private Queue<(GlobalDataKey key, object value)> _pendingDataChanges;
    private bool _isProcessingChanges;
    
    // 性能监控
    private Dictionary<int, float> _evaluationTimes;
    
    // GF组件引用
    private SettingComponent _settingComponent;
    private GameDataBlackboard _gameDataBlackboard;
    private ReferencePoolComponent _referencePool;
    

    
    // 外部接口1: 获取条件状态
    public ConditionState GetConditionState(int conditionId)
    {
        if (!_conditionStates.ContainsKey(conditionId))
        {
            CreateConditionState(conditionId);
        }
        return _conditionStates[conditionId];
    }
    
    // 外部接口2: 添加条件监听（使用弱引用）
    public void AddConditionListener(int conditionId, Action<ConditionState> listener)
    {
        if (!_conditionListeners.ContainsKey(conditionId))
            _conditionListeners[conditionId] = new List<WeakReference<Action<ConditionState>>>();
        
        _conditionListeners[conditionId].Add(new WeakReference<Action<ConditionState>>(listener));
    }
    
    // 移除条件监听
    public void RemoveConditionListener(int conditionId, Action<ConditionState> listener)
    {
        if (_conditionListeners.ContainsKey(conditionId))
        {
            _conditionListeners[conditionId].RemoveAll(wr => 
            {
                if (wr.TryGetTarget(out var target))
                    return target.Equals(listener);
                return true; // 移除无效的弱引用
            });
            
            if (_conditionListeners[conditionId].Count == 0)
                _conditionListeners.Remove(conditionId);
        }
    }
    
    protected override void Awake()
    {
        base.Awake();
        _conditionListeners = new Dictionary<int, List<WeakReference<Action<ConditionState>>>>();
        _conditionStates = new Dictionary<int, ConditionState>();
        _conditionConfigs = new Dictionary<int, cfg.ConditionSystem.Condition>();
        _groupToConditions = new Dictionary<ConditionGroup, List<int>>();
        _dataKeyToConditions = new Dictionary<GlobalDataKey, HashSet<int>>();
        _completedPermanentConditions = new HashSet<int>();
        _pendingDataChanges = new Queue<(GlobalDataKey, object)>();
        _evaluationTimes = new Dictionary<int, float>();
        _isProcessingChanges = false;
    }
    
    private void Start()
    {
        _settingComponent = GameEntry.GetComponent<SettingComponent>();
        _gameDataBlackboard = GameEntry.GetComponent<GameDataBlackboard>();
        
        LoadCompletedPermanentConditions();
        InitializeConditionConfigs();
        RegisterDataChangeListeners();
    }
    
    // 创建条件状态（懒加载 + 对象池）
    private void CreateConditionState(int conditionId)
    {
        if (!_conditionConfigs.ContainsKey(conditionId))
        {
            GameEntry.Log.Error($"Condition config not found for ID: {conditionId}");
            return;
        }
            
        var config = _conditionConfigs[conditionId];
        
        // 检测循环依赖
        if (HasCircularDependency(conditionId, new HashSet<int>()))
        {
            GameEntry.Log.Error($"Circular dependency detected for condition: {conditionId}");
            return;
        }
        
        // 从对象池获取条件状态
        var state = _referencePool.Acquire<ConditionState>();
        state.Initialize(conditionId);
        
        // 如果是已完成的永久条件，直接设置为完成状态
        if (config.IsPermanent && _completedPermanentConditions.Contains(conditionId))
        {
            state.IsCompleted = true;
            state.Progress = 1.0f;
            GameEntry.Log.Info($"Loaded completed permanent condition: {conditionId}");
        }
        else
        {
            // 动态评估当前状态
            EvaluateConditionState(config, state);
        }
        
        _conditionStates[conditionId] = state;
    }
    
    // 循环依赖检测
    private bool HasCircularDependency(int conditionId, HashSet<int> visitedConditions)
    {
        if (visitedConditions.Contains(conditionId)) 
        {
            GameEntry.Log.Warning($"Circular dependency detected in condition chain: {string.Join(" -> ", visitedConditions)} -> {conditionId}");
            return true;
        }
        
        if (!_conditionConfigs.ContainsKey(conditionId))
            return false;
            
        visitedConditions.Add(conditionId);
        var config = _conditionConfigs[conditionId];
        
        foreach (int subConditionId in config.SubConditions)
        {
            if (HasCircularDependency(subConditionId, visitedConditions))
                return true;
        }
        
        visitedConditions.Remove(conditionId);
        return false;
    }
    
    // 评估条件状态
    private void EvaluateConditionState(cfg.ConditionSystem.Condition config, ConditionState state)
    {
        var currentValue = _gameDataBlackboard.GetData<object>(config.DataKey);
        var evaluator = ConditionEvaluatorFactory.GetEvaluator(config.Type);
        
        if (evaluator != null)
        {
            evaluator.Evaluate(config, state, config.DataKey, currentValue);
        }
    }
    
    // 数据变化处理（延迟一帧处理）
    private void OnDataChanged(GlobalDataKey dataKey, object newValue)
    {
        _pendingDataChanges.Enqueue((dataKey, newValue));
        
        if (!_isProcessingChanges)
        {
            StartCoroutine(ProcessDataChangesNextFrame());
        }
    }
    
    // 下一帧处理数据变化
    private IEnumerator ProcessDataChangesNextFrame()
    {
        _isProcessingChanges = true;
        yield return null; // 等待下一帧
        
        // 按优先级分组处理
        var groupedChanges = new Dictionary<ConditionGroup, List<(GlobalDataKey, object)>>();
        
        while (_pendingDataChanges.Count > 0)
        {
            var (key, value) = _pendingDataChanges.Dequeue();
            
            if (_dataKeyToConditions.ContainsKey(key))
            {
                foreach (int conditionId in _dataKeyToConditions[key])
                {
                    var config = _conditionConfigs[conditionId];
                    var group = GetConditionGroup(config);
                    
                    if (!groupedChanges.ContainsKey(group))
                        groupedChanges[group] = new List<(GlobalDataKey, object)>();
                    
                    groupedChanges[group].Add((key, value));
                }
            }
        }
        
        // 按优先级顺序处理
        foreach (var group in groupedChanges.Keys.OrderBy(g => (int)g))
        {
            foreach (var (key, value) in groupedChanges[group])
            {
                ProcessDataChangeImmediately(key, value);
            }
        }
        
        _isProcessingChanges = false;
    }
    
    // 立即处理数据变化
    private void ProcessDataChangeImmediately(GlobalDataKey dataKey, object newValue)
    {
        if (_dataKeyToConditions.ContainsKey(dataKey))
        {
            foreach (int conditionId in _dataKeyToConditions[dataKey])
            {
                ProcessConditionDataChange(conditionId, dataKey, newValue);
            }
        }
    }
    
    // 处理条件数据变化
    private void ProcessConditionDataChange(int conditionId, GlobalDataKey dataKey, object newValue)
    {
        if (!_conditionConfigs.ContainsKey(conditionId))
            return;
            
        var config = _conditionConfigs[conditionId];
        var currentState = GetConditionState(conditionId);
        var previousState = CloneConditionState(currentState);
        
        // 如果是已完成的永久条件，不需要重新评估
        if (config.IsPermanent && _completedPermanentConditions.Contains(conditionId))
            return;
        
        var evaluator = ConditionEvaluatorFactory.GetEvaluator(config.Type);
        if (evaluator != null)
        {
            bool stateChanged = evaluator.Evaluate(config, currentState, dataKey, newValue);
            
            if (stateChanged)
            {
                // 如果是永久条件且刚完成，保存到本地存储
                if (config.IsPermanent && currentState.IsCompleted && !previousState.IsCompleted)
                {
                    _completedPermanentConditions.Add(conditionId);
                    SaveCompletedPermanentConditions();
                }
                
                // 通知监听者
                NotifyConditionChanged(conditionId, currentState);
            }
        }
    }
    
    // 通知条件变化
    private void NotifyConditionChanged(int conditionId, ConditionState newState)
    {
        if (_conditionListeners.ContainsKey(conditionId))
        {
            foreach (var listener in _conditionListeners[conditionId])
            {
                listener?.Invoke(newState);
            }
        }
    }
    
    // 加载已完成的永久条件
    private void LoadCompletedPermanentConditions()
    {
        string completedIds = _settingComponent.GetString("CompletedPermanentConditions", "");
        if (!string.IsNullOrEmpty(completedIds))
        {
            var ids = completedIds.Split(',');
            foreach (var idStr in ids)
            {
                if (int.TryParse(idStr, out int id))
                {
                    _completedPermanentConditions.Add(id);
                }
            }
        }
    }
    
    // 保存已完成的永久条件
    private void SaveCompletedPermanentConditions()
    {
        string completedIds = string.Join(",", _completedPermanentConditions);
        _settingComponent.SetString("CompletedPermanentConditions", completedIds);
    }
    
    // 初始化条件配置
    private void InitializeConditionConfigs()
    {
        var conditionTable = GameEntry.GetComponent<DataTableComponent>().GetDataTable<TbCondition>();
        
        foreach (var condition in conditionTable.DataList)
        {
            _conditionConfigs[condition.ConfigId] = condition;
            
            if (!_dataKeyToConditions.ContainsKey(condition.DataKey))
                _dataKeyToConditions[condition.DataKey] = new HashSet<int>();
                
            _dataKeyToConditions[condition.DataKey].Add(condition.ConfigId);
        }
    }
    
    // 注册数据变化监听
    private void RegisterDataChangeListeners()
    {
        foreach (var dataKey in _dataKeyToConditions.Keys)
        {
            _gameDataBlackboard.RegisterDataChangeListener(dataKey, (value) => OnDataChanged(dataKey, value));
        }
    }
    
    // 获取条件组（根据优先级确定）
    private ConditionGroup GetConditionGroup(cfg.ConditionSystem.Condition config)
    {
        // 这里需要根据配置表中的优先级字段来确定组
        // 暂时返回默认值，具体实现在任务中完成
        return ConditionGroup.Global;
    }
    
    // 定期清理无效的监听者引用
    private void CleanupInvalidListeners()
    {
        foreach (var kvp in _conditionListeners.ToList())
        {
            var validListeners = kvp.Value.Where(wr => wr.TryGetTarget(out _)).ToList();
            if (validListeners.Count == 0)
                _conditionListeners.Remove(kvp.Key);
            else
                _conditionListeners[kvp.Key] = validListeners;
        }
    }
    
    // 性能监控：记录条件评估时间
    private void RecordEvaluationTime(int conditionId, float evaluationTime)
    {
        _evaluationTimes[conditionId] = evaluationTime;
        
        if (evaluationTime > 0.001f) // 超过1ms记录警告
        {
            GameEntry.Log.Warning($"Condition {conditionId} evaluation took {evaluationTime * 1000:F2}ms");
        }
    }
    
    private ConditionState CloneConditionState(ConditionState original)
    {
        return JsonUtility.FromJson<ConditionState>(JsonUtility.ToJson(original));
    }
    
    // 组件销毁时清理资源
    protected override void OnDestroy()
    {
        // 清理监听者
        _conditionListeners.Clear();
        
        // 回收条件状态到对象池
        foreach (var state in _conditionStates.Values)
        {
            _referencePool.Release(state);
        }
        _conditionStates.Clear();
        
        base.OnDestroy();
    }
}
```

### 3. 数据监听层组件

#### GameDataBlackboard
游戏数据黑板，纯粹的数据中转站：

```csharp
public sealed class GameDataBlackboard : GameFrameworkComponent
{
    // 数据变更监听者
    private Dictionary<GlobalDataKey, HashSet<Action<object>>> _dataChangeListeners;
    
    // 初始化
    protected override void Awake()
    {
        base.Awake();
        _dataChangeListeners = new Dictionary<GlobalDataKey, HashSet<Action<object>>>();
    }
    
    // 外部接口1: 获取数据
    public T GetData<T>(GlobalDataKey key)
    {
        // 根据不同的数据键获取对应的数据
        return key switch
        {
            GlobalDataKey.ClaimedTaskRewards => GetClaimedTaskRewards<T>(),
            GlobalDataKey.MaxChapterCompleted => GetMaxChapterCompleted<T>(),
            GlobalDataKey.MaxTeammateLevel => GetMaxTeammateLevel<T>(),
            GlobalDataKey.DailyChapterRewardsClaimed => GetDailyChapterRewardsClaimed<T>(),
            GlobalDataKey.TotalChapterRewardsClaimed => GetTotalChapterRewardsClaimed<T>(),
            _ => default(T)
        };
    }
    
    // 外部接口2: 注册数据变更监听
    public void RegisterDataChangeListener(GlobalDataKey key, Action<object> listener)
    {
        if (!_dataChangeListeners.ContainsKey(key))
            _dataChangeListeners[key] = new HashSet<Action<object>>();
            
        _dataChangeListeners[key].Add(listener);
    }
    
    // 移除数据变更监听
    public void UnregisterDataChangeListener(GlobalDataKey key, Action<object> listener)
    {
        if (_dataChangeListeners.ContainsKey(key))
        {
            _dataChangeListeners[key].Remove(listener);
            if (_dataChangeListeners[key].Count == 0)
                _dataChangeListeners.Remove(key);
        }
    }
    
    // 内部方法：通知数据变更
    public void NotifyDataChanged(GlobalDataKey key, object newValue)
    {
        if (_dataChangeListeners.ContainsKey(key))
        {
            foreach (var listener in _dataChangeListeners[key])
            {
                listener?.Invoke(newValue);
            }
        }
    }
    
    // 具体数据获取方法的实现
    private T GetClaimedTaskRewards<T>()
    {
        // 从相应的游戏系统获取数据
        // 这里是示例实现
        return default(T);
    }
    
    private T GetMaxChapterCompleted<T>()
    {
        // 从相应的游戏系统获取数据
        return default(T);
    }
    
    private T GetMaxTeammateLevel<T>()
    {
        // 从相应的游戏系统获取数据
        return default(T);
    }
    
    private T GetDailyChapterRewardsClaimed<T>()
    {
        // 从相应的游戏系统获取数据
        return default(T);
    }
    
    private T GetTotalChapterRewardsClaimed<T>()
    {
        // 从相应的游戏系统获取数据
        return default(T);
    }
}
```

## 数据模型

### 条件评估器工厂

```csharp
public static class ConditionEvaluatorFactory
{
    private static readonly Dictionary<ConditionType, IConditionEvaluator> _evaluators;
    
    static ConditionEvaluatorFactory()
    {
        _evaluators = new Dictionary<ConditionType, IConditionEvaluator>
        {
            { ConditionType.NumericComparison, new NumericComparisonEvaluator() },
            { ConditionType.StringComparison, new StringComparisonEvaluator() },
            { ConditionType.BooleanCheck, new BooleanCheckEvaluator() },
            { ConditionType.EventCount, new EventCountEvaluator() },
            { ConditionType.EventAccumulation, new EventAccumulationEvaluator() },
            { ConditionType.TimeElapsed, new TimeElapsedEvaluator() },
            { ConditionType.TimeRemaining, new TimeRemainingEvaluator() },
            { ConditionType.CompositeCondition, new CompositeConditionEvaluator() },
            { ConditionType.Custom, new CustomEvaluator() }
        };
    }
    
    public static IConditionEvaluator GetEvaluator(ConditionType type)
    {
        return _evaluators.TryGetValue(type, out var evaluator) ? evaluator : null;
    }
}

public interface IConditionEvaluator
{
    bool Evaluate(cfg.ConditionSystem.Condition config, ConditionState state, GlobalDataKey dataKey, object value);
}
```

### 具体评估器实现

#### NumericComparisonEvaluator
数值比较评估器，处理数值类型的条件判断：

```csharp
public class NumericComparisonEvaluator : IConditionEvaluator
{
    public bool Evaluate(cfg.ConditionSystem.Condition config, ConditionState state, GlobalDataKey dataKey, object value)
    {
        if (config.Target is cfg.ConditionSystem.ConditionIntTarget intTarget)
        {
            int currentValue = Convert.ToInt32(value);
            int targetValue = intTarget.TargetValue;
            
            bool previousCompleted = state.IsCompleted;
            bool currentCompleted = CompareValues(currentValue, targetValue, config.Comparison);
            
            state.CurrentValue = currentValue;
            state.IsCompleted = currentCompleted;
            state.Progress = CalculateProgress(currentValue, targetValue, config.Comparison);
            state.LastUpdateTime = DateTime.Now;
            
            return previousCompleted != currentCompleted;
        }
        return false;
    }
    
    private bool CompareValues(int current, int target, ComparisonOperator op)
    {
        return op switch
        {
            ComparisonOperator.Equal => current == target,
            ComparisonOperator.NotEqual => current != target,
            ComparisonOperator.GreaterThan => current > target,
            ComparisonOperator.GreaterThanOrEqual => current >= target,
            ComparisonOperator.LessThan => current < target,
            ComparisonOperator.LessThanOrEqual => current <= target,
            _ => false
        };
    }
    
    private float CalculateProgress(int current, int target, ComparisonOperator op)
    {
        return op switch
        {
            ComparisonOperator.GreaterThanOrEqual or ComparisonOperator.GreaterThan => 
                target > 0 ? Mathf.Clamp01((float)current / target) : (current >= target ? 1.0f : 0.0f),
            ComparisonOperator.LessThanOrEqual or ComparisonOperator.LessThan => 
                current <= target ? 1.0f : 0.0f,
            ComparisonOperator.Equal => current == target ? 1.0f : 0.0f,
            ComparisonOperator.NotEqual => current != target ? 1.0f : 0.0f,
            _ => 0.0f
        };
    }
}
```

其他评估器类似实现：
- **StringComparisonEvaluator**: 字符串比较评估器
- **BooleanCheckEvaluator**: 布尔检查评估器
- **EventCountEvaluator**: 事件次数评估器
- **EventAccumulationEvaluator**: 事件累积值评估器
- **TimeElapsedEvaluator**: 经过时间评估器
- **TimeRemainingEvaluator**: 剩余时间评估器
- **CompositeConditionEvaluator**: 复合条件评估器
- **CustomEvaluator**: 自定义条件评估器

## 错误处理

### 异常类型定义

```csharp
public class ConditionSystemException : Exception
{
    public int ConditionId { get; }
    public ConditionSystemException(int conditionId, string message) : base(message)
    {
        ConditionId = conditionId;
    }
}

public class ConditionNotFoundException : ConditionSystemException
{
    public ConditionNotFoundException(int conditionId) 
        : base(conditionId, $"Condition with ID {conditionId} not found") { }
}

public class ConditionEvaluationException : ConditionSystemException
{
    public ConditionEvaluationException(int conditionId, Exception innerException)
        : base(conditionId, $"Failed to evaluate condition {conditionId}") 
    {
        InnerException = innerException;
    }
}
```

### 错误处理策略

1. **配置错误**: 在系统初始化时检测并记录配置错误
2. **运行时错误**: 提供降级策略，返回默认值并记录错误日志
3. **数据访问错误**: 实现重试机制和缓存降级
4. **循环依赖检测**: 在复合条件中检测并防止循环依赖



## 扩展性设计

### 自定义条件类型

系统支持通过插件方式添加自定义条件类型：

```csharp
public interface ICustomConditionEvaluator : IConditionEvaluator
{
    ConditionType SupportedType { get; }
    string TypeName { get; }
}
```

### 数据源扩展

支持添加新的数据源类型：

```csharp
public interface IDataSourceProvider
{
    bool CanProvide(GlobalDataKey key);
    T GetData<T>(GlobalDataKey key);
    void RegisterChangeCallback(GlobalDataKey key, Action callback);
}
```

### 存储后端扩展

支持不同的持久化存储实现：

```csharp
public interface IConditionStorageProvider
{
    string ProviderName { get; }
    IConditionStorage CreateStorage(string connectionString);
}
```