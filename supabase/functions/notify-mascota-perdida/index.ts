// Edge Function: notify-mascota-perdida
// Trigger: llamado directamente desde Flutter (HTTP POST) cuando una mascota
//          cambia su estado a 'perdido'.
//
// Propósito: Enviar push FCM a TODOS los usuarios con fcm_token activo,
//            excepto al dueño de la mascota (quien ya lo sabe).
//
// DESPLIEGUE:
//   supabase functions deploy notify-mascota-perdida
//
// VARIABLES DE ENTORNO (Supabase Dashboard → Settings → Edge Functions):
//   FIREBASE_SERVER_KEY = Server Key de Firebase (Proyecto → Cloud Messaging → Legacy API)
//
// BODY esperado (JSON):
//   {
//     "mascotaId":   "uuid-de-la-mascota",
//     "mascotaNombre": "Firulais",
//     "duenioId":    "uuid-del-duenio"   ← para excluirlo del broadcast
//   }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Permitir CORS para llamadas desde Flutter Web (ignorado en móvil)
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    const body = await req.json();
    const { mascotaId, mascotaNombre, duenioId } = body as {
      mascotaId: string;
      mascotaNombre: string;
      duenioId: string;
    };

    if (!mascotaId || !mascotaNombre || !duenioId) {
      return new Response(
        JSON.stringify({ error: "Faltan parámetros requeridos" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Cliente con service_role para leer todos los tokens sin restricciones RLS
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Obtener todos los tokens FCM activos, excluyendo al dueño de la mascota
    const { data: usuarios, error: errUsuarios } = await supabase
      .from("usuarios")
      .select("usua_id, fcm_token, usua_nombre")
      .not("fcm_token", "is", null)
      .neq("usua_id", duenioId);

    if (errUsuarios) {
      console.error("Error obteniendo tokens FCM:", errUsuarios);
      return new Response(
        JSON.stringify({ error: "Error consultando usuarios" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!usuarios || usuarios.length === 0) {
      console.log("No hay usuarios con fcm_token para notificar.");
      return new Response(
        JSON.stringify({ ok: true, enviados: 0, mensaje: "Sin destinatarios" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const firebaseServerKey = Deno.env.get("FIREBASE_SERVER_KEY")!;

    // FCM permite multicast de hasta 1000 tokens en una sola llamada
    // Dividimos en lotes de 500 para estar seguros
    const tokens: string[] = usuarios
      .map((u: { fcm_token: string }) => u.fcm_token)
      .filter(Boolean);

    const BATCH_SIZE = 500;
    let totalExitosos = 0;
    let totalFallidos = 0;

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const lote = tokens.slice(i, i + BATCH_SIZE);

      const fcmPayload = {
        // registration_ids permite enviar a múltiples tokens en un solo request
        registration_ids: lote,
        priority: "high",
        notification: {
          title: "🚨 ¡Mascota perdida!",
          body: `${mascotaNombre} está perdida. ¿Puedes ayudar a encontrarla?`,
          sound: "default",
          badge: "1",
          android_channel_id: "huellitas_urgente",
        },
        data: {
          tipo: "mascota_perdida",
          masc_id: mascotaId,
          mascota: mascotaNombre,
          urgente: "true",
          payload: "home",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      try {
        const fcmResponse = await fetch(
          "https://fcm.googleapis.com/fcm/send",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `key=${firebaseServerKey}`,
            },
            body: JSON.stringify(fcmPayload),
          }
        );

        const fcmResult = await fcmResponse.json();
        console.log(
          `Lote ${Math.floor(i / BATCH_SIZE) + 1}: success=${fcmResult.success}, failure=${fcmResult.failure}`
        );
        totalExitosos += fcmResult.success ?? 0;
        totalFallidos += fcmResult.failure ?? 0;
      } catch (batchError) {
        // Un lote fallido no detiene los demás
        console.error(`Error en lote ${Math.floor(i / BATCH_SIZE) + 1}:`, batchError);
        totalFallidos += lote.length;
      }
    }

    console.log(
      `Broadcast mascota perdida "${mascotaNombre}" completado. ` +
        `Exitosos: ${totalExitosos}, Fallidos: ${totalFallidos}`
    );

    return new Response(
      JSON.stringify({
        ok: true,
        enviados: totalExitosos,
        fallidos: totalFallidos,
        total: tokens.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("Error general en notify-mascota-perdida:", e);
    return new Response(
      JSON.stringify({ error: `Error interno: ${e}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
