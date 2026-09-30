using System;
using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Core
{
    /// <summary>
    /// Minimal service registry so runtime-spawned objects (units, buildings, projectiles)
    /// can reach scene managers without FindObjectOfType. Managers register in Awake
    /// and use [DefaultExecutionOrder] so they exist before gameplay objects enable.
    /// </summary>
    public static class GameServices
    {
        private static readonly Dictionary<Type, object> Services = new Dictionary<Type, object>();

        public static void Register<T>(T service) where T : class
        {
            if (Services.TryGetValue(typeof(T), out object existing) && !ReferenceEquals(existing, service))
            {
                Debug.LogWarning($"[GameServices] Replacing already registered service {typeof(T).Name}.");
            }

            Services[typeof(T)] = service;
        }

        public static void Unregister<T>(T service) where T : class
        {
            if (Services.TryGetValue(typeof(T), out object existing) && ReferenceEquals(existing, service))
            {
                Services.Remove(typeof(T));
            }
        }

        public static T Get<T>() where T : class
        {
            return Services.TryGetValue(typeof(T), out object service) ? (T)service : null;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics() => Services.Clear();
    }
}
