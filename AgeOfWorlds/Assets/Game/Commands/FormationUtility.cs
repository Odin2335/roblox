using System.Collections.Generic;
using AgeOfWorlds.Units;
using UnityEngine;
using UnityEngine.AI;

namespace AgeOfWorlds.Commands
{
    /// <summary>
    /// Computes one destination per unit so groups never share a single point.
    /// Units keep their relative arrangement (front units go to front slots, left to left),
    /// which avoids paths crossing through each other.
    /// </summary>
    public static class FormationUtility
    {
        private const int MaxLineWidth = 12;
        private const float LooseSpacingFactor = 1.6f;

        private static readonly List<int> Order = new List<int>();
        private static readonly List<Vector3> SlotBuffer = new List<Vector3>();

        /// <param name="results">Filled so that results[i] is the destination of units[i].</param>
        public static void ComputeDestinations(
            IReadOnlyList<Unit> units,
            Vector3 destination,
            FormationType formation,
            float spacing,
            List<Vector3> results)
        {
            results.Clear();
            int count = units.Count;
            if (count == 0)
            {
                return;
            }

            Vector3 centroid = Vector3.zero;
            for (int i = 0; i < count; i++)
            {
                centroid += units[i].transform.position;
                results.Add(destination);
            }

            centroid /= count;

            Vector3 forward = destination - centroid;
            forward.y = 0f;
            forward = forward.sqrMagnitude > 0.01f ? forward.normalized : Vector3.forward;
            Vector3 right = Vector3.Cross(Vector3.up, forward);

            int columns = GetColumns(formation, count);
            int rows = Mathf.CeilToInt(count / (float)columns);
            float slotSpacing = formation == FormationType.Loose ? spacing * LooseSpacingFactor : spacing;

            // Sort units front-to-back relative to the movement direction.
            Order.Clear();
            for (int i = 0; i < count; i++)
            {
                Order.Add(i);
            }

            Order.Sort((a, b) =>
                Vector3.Dot(units[b].transform.position - centroid, forward)
                    .CompareTo(Vector3.Dot(units[a].transform.position - centroid, forward)));

            for (int row = 0; row < rows; row++)
            {
                int start = row * columns;
                int inRow = Mathf.Min(columns, count - start);

                // Within a row, sort left-to-right so each unit takes the slot on its side.
                Order.Sort(start, inRow, Comparer<int>.Create((a, b) =>
                    Vector3.Dot(units[a].transform.position - centroid, right)
                        .CompareTo(Vector3.Dot(units[b].transform.position - centroid, right))));

                BuildRowSlots(destination, forward, right, formation, slotSpacing, row, rows, inRow, start);

                for (int column = 0; column < inRow; column++)
                {
                    results[Order[start + column]] = SlotBuffer[column];
                }
            }
        }

        private static int GetColumns(FormationType formation, int count)
        {
            switch (formation)
            {
                case FormationType.Line:
                    int ranks = Mathf.CeilToInt(count / (float)MaxLineWidth);
                    return Mathf.CeilToInt(count / (float)ranks);
                default:
                    return Mathf.CeilToInt(Mathf.Sqrt(count));
            }
        }

        private static void BuildRowSlots(
            Vector3 destination, Vector3 forward, Vector3 right, FormationType formation,
            float spacing, int row, int rows, int inRow, int firstIndex)
        {
            SlotBuffer.Clear();
            float rowZ = -(row - (rows - 1) * 0.5f) * spacing;

            for (int column = 0; column < inRow; column++)
            {
                float x = (column - (inRow - 1) * 0.5f) * spacing;
                float z = rowZ;

                if (formation == FormationType.Loose)
                {
                    // Deterministic jitter so loose groups look natural but stay stable.
                    int seed = firstIndex + column;
                    x += (Hash01(seed) - 0.5f) * spacing * 0.4f;
                    z += (Hash01(seed * 7 + 3) - 0.5f) * spacing * 0.4f;
                }

                Vector3 slot = destination + right * x + forward * z;
                SlotBuffer.Add(NavMesh.SamplePosition(slot, out NavMeshHit hit, spacing * 2f, NavMesh.AllAreas)
                    ? hit.position
                    : destination);
            }
        }

        private static float Hash01(int value)
        {
            unchecked
            {
                uint h = (uint)value * 2654435761u;
                h ^= h >> 16;
                return (h & 0xFFFF) / 65535f;
            }
        }
    }
}
