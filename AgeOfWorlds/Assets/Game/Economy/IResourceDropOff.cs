using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// A place where workers deposit carried resources. Which resources are accepted
    /// is pure data, so Town Center, Lumber Camp, Mining Camp or an energy building
    /// all use the same code path.
    /// </summary>
    public interface IResourceDropOff
    {
        Transform Transform { get; }
        int OwnerId { get; }
        /// <summary>False while under construction (Phase 3) or destroyed.</summary>
        bool IsOperational { get; }
        bool Accepts(ResourceType type);
        /// <summary>Closest point on the drop-off's outline, seen from a position.</summary>
        Vector3 GetClosestPoint(Vector3 from);
    }
}
