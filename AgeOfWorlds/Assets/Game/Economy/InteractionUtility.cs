using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>Distance helpers for "is the unit close enough to work on this object".</summary>
    public static class InteractionUtility
    {
        public static Vector3 ClosestPoint(Collider collider, Transform fallback, Vector3 from)
        {
            return collider != null && collider.enabled ? collider.ClosestPoint(from) : fallback.position;
        }

        /// <summary>Flat (XZ) distance between a position and the closest point of a target.</summary>
        public static float FlatDistance(Vector3 from, Vector3 closestPoint)
        {
            Vector3 offset = closestPoint - from;
            offset.y = 0f;
            return offset.magnitude;
        }
    }
}
