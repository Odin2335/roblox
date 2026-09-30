using UnityEngine;

namespace AgeOfWorlds.Core
{
    /// <summary>Anything the player can click and inspect: units now, buildings and resource nodes later.</summary>
    public interface ISelectable
    {
        Transform Transform { get; }
        int OwnerId { get; }
        bool IsSelectable { get; }
        float SelectionRadius { get; }
        string DisplayName { get; }
        Sprite Icon { get; }
        float CurrentHealth { get; }
        float MaxHealth { get; }
    }
}
