/** Explicit local rules; no network model is implied while offline. */
export function localCommercialPlan(texto:string){
 const t=texto.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'');
 const categoria=/anticr/.test(t)?'Anticretico':/alquil|renta|arriend/.test(t)?'Alquiler':/visit|conocer|ver el|ver la|recorrer/.test(t)?'Visita':/precio|cuanto|costo|rebaja|descuento|negoci/.test(t)?'Precio':/compr|venta|adquirir/.test(t)?'Compra':'Otro';
 const urgencia=/urgente|hoy|ya mismo|inmediat|firmar|cerrar trato|reservar/.test(t)?'Alta':/solo informacion|curiosidad|mas adelante|el proximo ano/.test(t)?'Baja':'Media';
 const action:Record<string,string>={Visita:'Coordinar fecha y confirmar la visita',Precio:'Preparar propuesta y revisar presupuesto',Compra:'Seleccionar inmuebles para compra',Alquiler:'Revisar requisitos y opciones de alquiler',Anticretico:'Revisar condiciones de anticrético'};
 return {categoria,urgencia,modo:'reglas_offline',justificacion:'Clasificación por palabras clave; el servidor revisará el plan al sincronizar.',estado:'Pendiente',tareas:['Contactar al interesado y validar sus datos',action[categoria]||'Aclarar necesidades y preferencias','Registrar resultado y siguiente contacto en la oportunidad'].map((titulo,i)=>{const d=new Date();d.setDate(d.getDate()+(urgencia==='Alta'?0:urgencia==='Baja'?3:1)+i);return {titulo,completada:false,vence:[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-')};})};
}
