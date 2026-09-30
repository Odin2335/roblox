using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Core.Spatial
{
    /// <summary>
    /// Uniform grid on the XZ plane for cheap neighbour queries (separation now,
    /// target scanning and splash damage later). Rebuilt on manager ticks, not every frame.
    /// </summary>
    public class SpatialHashGrid<T> where T : Component
    {
        private readonly float cellSize;
        private readonly float inverseCellSize;
        private readonly Dictionary<long, List<T>> cells = new Dictionary<long, List<T>>();
        private readonly Stack<List<T>> listPool = new Stack<List<T>>();

        public SpatialHashGrid(float cellSize)
        {
            this.cellSize = Mathf.Max(0.5f, cellSize);
            inverseCellSize = 1f / this.cellSize;
        }

        public void Clear()
        {
            foreach (List<T> list in cells.Values)
            {
                list.Clear();
                listPool.Push(list);
            }

            cells.Clear();
        }

        public void Insert(T item)
        {
            Vector3 position = item.transform.position;
            long key = Key(Cell(position.x), Cell(position.z));
            if (!cells.TryGetValue(key, out List<T> list))
            {
                list = listPool.Count > 0 ? listPool.Pop() : new List<T>();
                cells.Add(key, list);
            }

            list.Add(item);
        }

        /// <summary>Adds every item whose position lies within radius of center. Does not clear results.</summary>
        public void Query(Vector3 center, float radius, List<T> results)
        {
            float radiusSqr = radius * radius;
            int minX = Cell(center.x - radius);
            int maxX = Cell(center.x + radius);
            int minZ = Cell(center.z - radius);
            int maxZ = Cell(center.z + radius);

            for (int x = minX; x <= maxX; x++)
            {
                for (int z = minZ; z <= maxZ; z++)
                {
                    if (!cells.TryGetValue(Key(x, z), out List<T> list))
                    {
                        continue;
                    }

                    for (int i = 0; i < list.Count; i++)
                    {
                        Vector3 offset = list[i].transform.position - center;
                        offset.y = 0f;
                        if (offset.sqrMagnitude <= radiusSqr)
                        {
                            results.Add(list[i]);
                        }
                    }
                }
            }
        }

        private int Cell(float coordinate) => Mathf.FloorToInt(coordinate * inverseCellSize);

        private static long Key(int x, int z) => ((long)x << 32) ^ (uint)z;
    }
}
