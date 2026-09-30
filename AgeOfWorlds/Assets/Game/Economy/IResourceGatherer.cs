using AgeOfWorlds.Data;

namespace AgeOfWorlds.Economy
{
    public interface IResourceGatherer
    {
        int CarryCapacity { get; }
        float GatherRate { get; }
        int CurrentCarryAmount { get; }
        ResourceType CarriedResourceType { get; }
        ResourceNode CurrentResourceNode { get; }
        IResourceDropOff CurrentDropOff { get; }
    }
}
