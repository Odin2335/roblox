using AgeOfWorlds.Economy;
using UnityEngine;

namespace AgeOfWorlds.Units
{
    /// <summary>Command types grow with each phase (Attack, Build, Patrol ...).</summary>
    public enum UnitCommandType
    {
        Stop,
        Move,
        Gather,
        ReturnResource
    }

    /// <summary>A single order for one unit. Created by the CommandManager or the AI.</summary>
    public readonly struct UnitCommand
    {
        public readonly UnitCommandType Type;
        public readonly Vector3 Position;
        public readonly Component Target;

        private UnitCommand(UnitCommandType type, Vector3 position, Component target)
        {
            Type = type;
            Position = position;
            Target = target;
        }

        public static UnitCommand Stop() => new UnitCommand(UnitCommandType.Stop, Vector3.zero, null);

        public static UnitCommand Move(Vector3 destination) =>
            new UnitCommand(UnitCommandType.Move, destination, null);

        public static UnitCommand Gather(ResourceNode node) =>
            new UnitCommand(UnitCommandType.Gather, node.transform.position, node);

        /// <param name="dropOff">Optional. Null = nearest valid drop-off.</param>
        public static UnitCommand ReturnResource(ResourceDropOff dropOff) =>
            new UnitCommand(UnitCommandType.ReturnResource, dropOff != null ? dropOff.transform.position : Vector3.zero, dropOff);
    }
}
