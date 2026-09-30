using System;
using System.Collections.Generic;
using UnityEngine;

namespace AgeOfWorlds.Core
{
    /// <summary>
    /// Typed, allocation-free publish/subscribe hub. Events are structs.
    /// Subscribers must unsubscribe in OnDisable/OnDestroy.
    /// </summary>
    public static class EventBus
    {
        private static readonly Dictionary<Type, Delegate> Handlers = new Dictionary<Type, Delegate>();

        public static void Subscribe<T>(Action<T> handler) where T : struct
        {
            Type type = typeof(T);
            Handlers[type] = Handlers.TryGetValue(type, out Delegate existing)
                ? Delegate.Combine(existing, handler)
                : handler;
        }

        public static void Unsubscribe<T>(Action<T> handler) where T : struct
        {
            Type type = typeof(T);
            if (!Handlers.TryGetValue(type, out Delegate existing))
            {
                return;
            }

            Delegate remaining = Delegate.Remove(existing, handler);
            if (remaining == null)
            {
                Handlers.Remove(type);
            }
            else
            {
                Handlers[type] = remaining;
            }
        }

        public static void Publish<T>(T evt) where T : struct
        {
            if (Handlers.TryGetValue(typeof(T), out Delegate handler))
            {
                ((Action<T>)handler).Invoke(evt);
            }
        }

        // Supports "Enter Play Mode Options" with domain reload disabled.
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics() => Handlers.Clear();
    }
}
