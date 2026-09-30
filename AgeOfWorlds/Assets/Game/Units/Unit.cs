using AgeOfWorlds.Core;
using AgeOfWorlds.Data;
using AgeOfWorlds.Economy;
using AgeOfWorlds.Economy.Workers;
using AgeOfWorlds.Units.States;
using UnityEngine;

namespace AgeOfWorlds.Units
{
    /// <summary>
    /// Runtime unit. Holds identity (data + owner), health and the state machine.
    /// Behaviour lives in reusable states; capabilities (gathering, combat) are added as components later.
    /// </summary>
    [RequireComponent(typeof(UnitMovement))]
    public class Unit : MonoBehaviour, ISelectable
    {
        [SerializeField] private UnitData data;
        [SerializeField] private int ownerId;

        private UnitManager unitManager;
        private UnitMovement movement;
        private UnitStateMachine stateMachine;
        private Worker worker;
        private bool workerLookedUp;

        public UnitData Data => data;
        public int OwnerId => ownerId;

        // Lazy so sibling components can use them regardless of Awake order.
        public UnitMovement Movement => movement != null ? movement : movement = GetComponent<UnitMovement>();
        public UnitStateMachine StateMachine => stateMachine ??= new UnitStateMachine();

        /// <summary>The worker capability, or null if this unit cannot gather/build.</summary>
        public Worker Worker
        {
            get
            {
                if (!workerLookedUp)
                {
                    worker = GetComponent<Worker>();
                    workerLookedUp = true;
                }

                return worker;
            }
        }

        public float CurrentHealth { get; private set; }
        public float MaxHealth => data != null ? data.MaxHealth : 1f;
        public bool IsAlive => CurrentHealth > 0f;

        /// <summary>Index inside UnitManager's list for O(1) removal. Managed by UnitManager only.</summary>
        internal int RegistryIndex { get; set; } = -1;

        // ISelectable
        public Transform Transform => transform;
        public bool IsSelectable => isActiveAndEnabled && IsAlive;
        public float SelectionRadius => data != null ? data.Radius : 0.5f;
        public string DisplayName => data != null ? data.DisplayName : name;
        public Sprite Icon => data != null ? data.Icon : null;

        /// <summary>Used by spawners (production, pooling) before the unit is activated.</summary>
        public void Initialize(UnitData unitData, int owner)
        {
            data = unitData;
            ownerId = owner;
        }

        private void OnEnable()
        {
            if (data == null)
            {
                Debug.LogError($"[Unit] {name} has no UnitData assigned.", this);
            }

            CurrentHealth = MaxHealth;
            Movement.Configure(data);
            StateMachine.ChangeState(new UnitIdleState(this));

            unitManager = GameServices.Get<UnitManager>();
            if (unitManager != null)
            {
                unitManager.Register(this);
            }
            else
            {
                Debug.LogError("[Unit] No UnitManager in the scene.", this);
            }
        }

        private void OnDisable()
        {
            unitManager?.Unregister(this);
            unitManager = null;
        }

        public void ExecuteCommand(in UnitCommand command)
        {
            if (!IsAlive)
            {
                return;
            }

            switch (command.Type)
            {
                case UnitCommandType.Move:
                    StateMachine.ChangeState(new UnitMoveState(this, command.Position));
                    break;
                case UnitCommandType.Stop:
                    Movement.Stop();
                    StateMachine.ChangeState(new UnitIdleState(this));
                    break;
                case UnitCommandType.Gather:
                    if (Worker != null && command.Target is ResourceNode node)
                    {
                        Worker.BeginGathering(node);
                    }
                    else
                    {
                        StateMachine.ChangeState(new UnitMoveState(this, command.Position));
                    }

                    break;
                case UnitCommandType.ReturnResource:
                    if (Worker != null)
                    {
                        Worker.ReturnCargo(command.Target as ResourceDropOff);
                    }

                    break;
            }
        }
    }
}
