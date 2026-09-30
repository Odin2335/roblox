using UnityEngine;

namespace AgeOfWorlds.Units
{
    /// <summary>Command types grow with each phase (Attack, Gather, Build, Patrol ...).</summary>
    public enum UnitCommandType
    {
        Stop,
        Move
    }

    /// <summary>A single order for one unit. Created by the CommandManager or the AI.</summary>
    public readonly struct UnitCommand
    {
        public readonly UnitCommandType Type;
        public readonly Vector3 Position;

        private UnitCommand(UnitCommandType type, Vector3 position)
        {
            Type = type;
            Position = position;
        }

        public static UnitCommand Stop() => new UnitCommand(UnitCommandType.Stop, Vector3.zero);
        public static UnitCommand Move(Vector3 destination) => new UnitCommand(UnitCommandType.Move, destination);
    }
}
