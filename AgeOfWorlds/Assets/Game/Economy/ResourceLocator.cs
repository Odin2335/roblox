using System.Collections.Generic;
using AgeOfWorlds.Core;
using AgeOfWorlds.Data;
using UnityEngine;

namespace AgeOfWorlds.Economy
{
    /// <summary>
    /// Registry of resource nodes and drop-offs with nearest-X queries.
    /// Queries only run on events (node depleted, cargo full), not every frame.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class ResourceLocator : MonoBehaviour
    {
        private readonly List<ResourceNode>[] nodesByType = CreateNodeLists();
        private readonly List<IResourceDropOff> dropOffs = new List<IResourceDropOff>();

        private void Awake()
        {
            GameServices.Register(this);
        }

        private void OnDestroy()
        {
            GameServices.Unregister(this);
        }

        public void Register(ResourceNode node)
        {
            List<ResourceNode> list = nodesByType[(int)node.ResourceType];
            if (!list.Contains(node))
            {
                list.Add(node);
            }
        }

        public void Unregister(ResourceNode node) => nodesByType[(int)node.ResourceType].Remove(node);

        public void Register(IResourceDropOff dropOff)
        {
            if (!dropOffs.Contains(dropOff))
            {
                dropOffs.Add(dropOff);
            }
        }

        public void Unregister(IResourceDropOff dropOff) => dropOffs.Remove(dropOff);

        /// <summary>Nearest non-depleted node of a type within maxDistance, or null.</summary>
        public ResourceNode FindNearestNode(ResourceType type, Vector3 position, float maxDistance, ResourceNode exclude = null)
        {
            List<ResourceNode> list = nodesByType[(int)type];
            ResourceNode best = null;
            float bestSqr = maxDistance * maxDistance;

            for (int i = 0; i < list.Count; i++)
            {
                ResourceNode node = list[i];
                if (node == exclude || node.IsDepleted)
                {
                    continue;
                }

                float sqr = FlatSqrDistance(position, node.transform.position);
                if (sqr <= bestSqr)
                {
                    bestSqr = sqr;
                    best = node;
                }
            }

            return best;
        }

        /// <summary>Nearest operational drop-off of the player that accepts the resource type, or null.</summary>
        public IResourceDropOff FindNearestDropOff(int ownerId, ResourceType type, Vector3 position)
        {
            IResourceDropOff best = null;
            float bestSqr = float.MaxValue;

            for (int i = 0; i < dropOffs.Count; i++)
            {
                IResourceDropOff dropOff = dropOffs[i];
                if (dropOff.OwnerId != ownerId || !dropOff.IsOperational || !dropOff.Accepts(type))
                {
                    continue;
                }

                float sqr = FlatSqrDistance(position, dropOff.GetClosestPoint(position));
                if (sqr < bestSqr)
                {
                    bestSqr = sqr;
                    best = dropOff;
                }
            }

            return best;
        }

        private static float FlatSqrDistance(Vector3 a, Vector3 b)
        {
            float dx = a.x - b.x;
            float dz = a.z - b.z;
            return dx * dx + dz * dz;
        }

        private static List<ResourceNode>[] CreateNodeLists()
        {
            var lists = new List<ResourceNode>[ResourceTypeUtility.Count];
            for (int i = 0; i < lists.Length; i++)
            {
                lists[i] = new List<ResourceNode>();
            }

            return lists;
        }
    }
}
