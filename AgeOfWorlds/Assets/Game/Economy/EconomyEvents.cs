using AgeOfWorlds.Data;
using AgeOfWorlds.Economy.Workers;

namespace AgeOfWorlds.Economy
{
    public readonly struct ResourceChangedEvent
    {
        public readonly int PlayerId;
        public readonly ResourceType Type;
        public readonly int Amount;
        public readonly int Delta;

        public ResourceChangedEvent(int playerId, ResourceType type, int amount, int delta)
        {
            PlayerId = playerId;
            Type = type;
            Amount = amount;
            Delta = delta;
        }
    }

    public readonly struct PopulationChangedEvent
    {
        public readonly int PlayerId;
        public readonly int Current;
        public readonly int Max;

        public PopulationChangedEvent(int playerId, int current, int max)
        {
            PlayerId = playerId;
            Current = current;
            Max = max;
        }
    }

    public readonly struct ResourceNodeDepletedEvent
    {
        public readonly ResourceNode Node;
        public ResourceNodeDepletedEvent(ResourceNode node) => Node = node;
    }

    public readonly struct WorkerIdleChangedEvent
    {
        public readonly Worker Worker;
        public readonly bool IsIdle;

        public WorkerIdleChangedEvent(Worker worker, bool isIdle)
        {
            Worker = worker;
            IsIdle = isIdle;
        }
    }

    public readonly struct IdleWorkerCountChangedEvent
    {
        public readonly int PlayerId;
        public readonly int Count;

        public IdleWorkerCountChangedEvent(int playerId, int count)
        {
            PlayerId = playerId;
            Count = count;
        }
    }
}
