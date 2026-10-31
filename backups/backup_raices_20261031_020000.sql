--
-- PostgreSQL database dump
--

\restrict sUDV8mGcGoYNQjgbpH2F0B3mn7rhP8kJc2SA8Lx6uxPEEH3glSwASwRO9qltqPs

-- Dumped from database version 16.15 (Debian 16.15-1.pgdg12+2)
-- Dumped by pg_dump version 18.6 (Debian 18.6-1.pgdg12+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.visita DROP CONSTRAINT IF EXISTS visita_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.visita DROP CONSTRAINT IF EXISTS visita_id_propiedad_fkey;
ALTER TABLE IF EXISTS ONLY public.visita DROP CONSTRAINT IF EXISTS visita_id_cliente_fkey;
ALTER TABLE IF EXISTS ONLY public.visita DROP CONSTRAINT IF EXISTS visita_id_agente_fkey;
ALTER TABLE IF EXISTS ONLY public.usuario_sucursal DROP CONSTRAINT IF EXISTS usuario_sucursal_id_sucursal_fkey;
ALTER TABLE IF EXISTS ONLY public.usuario_sucursal DROP CONSTRAINT IF EXISTS usuario_sucursal_ci_usuario_fkey;
ALTER TABLE IF EXISTS ONLY public.usuario DROP CONSTRAINT IF EXISTS usuario_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.usuario DROP CONSTRAINT IF EXISTS usuario_id_rol_fkey;
ALTER TABLE IF EXISTS ONLY public.suscripcion_saas DROP CONSTRAINT IF EXISTS suscripcion_saas_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.suscripcion_saas DROP CONSTRAINT IF EXISTS suscripcion_saas_codigo_plan_fkey;
ALTER TABLE IF EXISTS ONLY public.sucursal DROP CONSTRAINT IF EXISTS sucursal_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.rol_permiso DROP CONSTRAINT IF EXISTS rol_permiso_id_rol_fkey;
ALTER TABLE IF EXISTS ONLY public.rol_permiso DROP CONSTRAINT IF EXISTS rol_permiso_id_permiso_fkey;
ALTER TABLE IF EXISTS ONLY public.rol DROP CONSTRAINT IF EXISTS rol_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.reporte_guardado DROP CONSTRAINT IF EXISTS reporte_guardado_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.reporte_guardado DROP CONSTRAINT IF EXISTS reporte_guardado_ci_usuario_fkey;
ALTER TABLE IF EXISTS ONLY public.propietario DROP CONSTRAINT IF EXISTS propietario_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.propietario DROP CONSTRAINT IF EXISTS propietario_ci_usuario_fkey;
ALTER TABLE IF EXISTS ONLY public.propiedad DROP CONSTRAINT IF EXISTS propiedad_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.propiedad DROP CONSTRAINT IF EXISTS propiedad_id_sucursal_fkey;
ALTER TABLE IF EXISTS ONLY public.propiedad DROP CONSTRAINT IF EXISTS propiedad_id_propietario_fkey;
ALTER TABLE IF EXISTS ONLY public.propiedad DROP CONSTRAINT IF EXISTS propiedad_id_agente_fkey;
ALTER TABLE IF EXISTS ONLY public.pago DROP CONSTRAINT IF EXISTS pago_id_contrato_fkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_id_sucursal_fkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_id_propiedad_fkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_id_contrato_fkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_id_cliente_fkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_ci_usuario_fkey;
ALTER TABLE IF EXISTS ONLY public.imagen DROP CONSTRAINT IF EXISTS imagen_id_propiedad_fkey;
ALTER TABLE IF EXISTS ONLY public.cuota DROP CONSTRAINT IF EXISTS cuota_id_contrato_fkey;
ALTER TABLE IF EXISTS ONLY public.contrato DROP CONSTRAINT IF EXISTS contrato_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.contrato DROP CONSTRAINT IF EXISTS contrato_id_propiedad_fkey;
ALTER TABLE IF EXISTS ONLY public.contrato DROP CONSTRAINT IF EXISTS contrato_id_cliente_fkey;
ALTER TABLE IF EXISTS ONLY public.contrato DROP CONSTRAINT IF EXISTS contrato_id_agente_fkey;
ALTER TABLE IF EXISTS ONLY public.cliente DROP CONSTRAINT IF EXISTS cliente_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.cliente DROP CONSTRAINT IF EXISTS cliente_ci_usuario_fkey;
ALTER TABLE IF EXISTS ONLY public.caracteristica DROP CONSTRAINT IF EXISTS caracteristica_id_propiedad_fkey;
ALTER TABLE IF EXISTS ONLY public.bitacora DROP CONSTRAINT IF EXISTS bitacora_ci_usuario_fkey;
ALTER TABLE IF EXISTS ONLY public.agente DROP CONSTRAINT IF EXISTS agente_id_tenant_fkey;
ALTER TABLE IF EXISTS ONLY public.agente DROP CONSTRAINT IF EXISTS agente_ci_usuario_fkey;
DROP INDEX IF EXISTS public.ix_visita_id_visita;
DROP INDEX IF EXISTS public.ix_usuario_correo;
DROP INDEX IF EXISTS public.ix_usuario_ci;
DROP INDEX IF EXISTS public.ix_tenant_slug;
DROP INDEX IF EXISTS public.ix_tenant_id_tenant;
DROP INDEX IF EXISTS public.ix_sucursal_id_tenant;
DROP INDEX IF EXISTS public.ix_rol_id_rol;
DROP INDEX IF EXISTS public.ix_reporte_guardado_id_reporte;
DROP INDEX IF EXISTS public.ix_propietario_id_propietario;
DROP INDEX IF EXISTS public.ix_propiedad_id_sucursal;
DROP INDEX IF EXISTS public.ix_propiedad_id_propiedad;
DROP INDEX IF EXISTS public.ix_permiso_id_permiso;
DROP INDEX IF EXISTS public.ix_pago_id_pago;
DROP INDEX IF EXISTS public.ix_operacion_offline_id_tenant;
DROP INDEX IF EXISTS public.ix_imagen_id_imagen;
DROP INDEX IF EXISTS public.ix_cuota_id_cuota;
DROP INDEX IF EXISTS public.ix_contrato_id_contrato;
DROP INDEX IF EXISTS public.ix_cliente_id_cliente;
DROP INDEX IF EXISTS public.ix_caracteristica_id_caracteristica;
DROP INDEX IF EXISTS public.ix_bitacora_id_bitacora;
DROP INDEX IF EXISTS public.ix_agente_id_agente;
ALTER TABLE IF EXISTS ONLY public.visita DROP CONSTRAINT IF EXISTS visita_pkey;
ALTER TABLE IF EXISTS ONLY public.usuario_sucursal DROP CONSTRAINT IF EXISTS usuario_sucursal_pkey;
ALTER TABLE IF EXISTS ONLY public.usuario DROP CONSTRAINT IF EXISTS usuario_pkey;
ALTER TABLE IF EXISTS ONLY public.usuario DROP CONSTRAINT IF EXISTS uq_usuario_tenant_correo;
ALTER TABLE IF EXISTS ONLY public.usuario DROP CONSTRAINT IF EXISTS uq_usuario_tenant_ci;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS uq_offline_tenant_uuid;
ALTER TABLE IF EXISTS ONLY public.tenant DROP CONSTRAINT IF EXISTS tenant_pkey;
ALTER TABLE IF EXISTS ONLY public.suscripcion_saas DROP CONSTRAINT IF EXISTS suscripcion_saas_pkey;
ALTER TABLE IF EXISTS ONLY public.sucursal DROP CONSTRAINT IF EXISTS sucursal_pkey;
ALTER TABLE IF EXISTS ONLY public.sucursal DROP CONSTRAINT IF EXISTS sucursal_id_tenant_nombre_key;
ALTER TABLE IF EXISTS ONLY public.rol DROP CONSTRAINT IF EXISTS rol_pkey;
ALTER TABLE IF EXISTS ONLY public.rol_permiso DROP CONSTRAINT IF EXISTS rol_permiso_pkey;
ALTER TABLE IF EXISTS ONLY public.reporte_guardado DROP CONSTRAINT IF EXISTS reporte_guardado_pkey;
ALTER TABLE IF EXISTS ONLY public.propietario DROP CONSTRAINT IF EXISTS propietario_pkey;
ALTER TABLE IF EXISTS ONLY public.propietario DROP CONSTRAINT IF EXISTS propietario_ci_usuario_key;
ALTER TABLE IF EXISTS ONLY public.propiedad DROP CONSTRAINT IF EXISTS propiedad_pkey;
ALTER TABLE IF EXISTS ONLY public.plan_saas DROP CONSTRAINT IF EXISTS plan_saas_pkey;
ALTER TABLE IF EXISTS ONLY public.permiso DROP CONSTRAINT IF EXISTS permiso_pkey;
ALTER TABLE IF EXISTS ONLY public.permiso DROP CONSTRAINT IF EXISTS permiso_codigo_key;
ALTER TABLE IF EXISTS ONLY public.pago DROP CONSTRAINT IF EXISTS pago_pkey;
ALTER TABLE IF EXISTS ONLY public.operacion_offline DROP CONSTRAINT IF EXISTS operacion_offline_pkey;
ALTER TABLE IF EXISTS ONLY public.imagen DROP CONSTRAINT IF EXISTS imagen_pkey;
ALTER TABLE IF EXISTS ONLY public.cuota DROP CONSTRAINT IF EXISTS cuota_pkey;
ALTER TABLE IF EXISTS ONLY public.contrato DROP CONSTRAINT IF EXISTS contrato_pkey;
ALTER TABLE IF EXISTS ONLY public.cliente DROP CONSTRAINT IF EXISTS cliente_pkey;
ALTER TABLE IF EXISTS ONLY public.cliente DROP CONSTRAINT IF EXISTS cliente_ci_usuario_key;
ALTER TABLE IF EXISTS ONLY public.caracteristica DROP CONSTRAINT IF EXISTS caracteristica_pkey;
ALTER TABLE IF EXISTS ONLY public.bitacora DROP CONSTRAINT IF EXISTS bitacora_pkey;
ALTER TABLE IF EXISTS ONLY public.agente DROP CONSTRAINT IF EXISTS agente_pkey;
ALTER TABLE IF EXISTS ONLY public.agente DROP CONSTRAINT IF EXISTS agente_ci_usuario_key;
ALTER TABLE IF EXISTS public.visita ALTER COLUMN id_visita DROP DEFAULT;
ALTER TABLE IF EXISTS public.tenant ALTER COLUMN id_tenant DROP DEFAULT;
ALTER TABLE IF EXISTS public.sucursal ALTER COLUMN id_sucursal DROP DEFAULT;
ALTER TABLE IF EXISTS public.rol ALTER COLUMN id_rol DROP DEFAULT;
ALTER TABLE IF EXISTS public.reporte_guardado ALTER COLUMN id_reporte DROP DEFAULT;
ALTER TABLE IF EXISTS public.propietario ALTER COLUMN id_propietario DROP DEFAULT;
ALTER TABLE IF EXISTS public.propiedad ALTER COLUMN id_propiedad DROP DEFAULT;
ALTER TABLE IF EXISTS public.permiso ALTER COLUMN id_permiso DROP DEFAULT;
ALTER TABLE IF EXISTS public.pago ALTER COLUMN id_pago DROP DEFAULT;
ALTER TABLE IF EXISTS public.operacion_offline ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.imagen ALTER COLUMN id_imagen DROP DEFAULT;
ALTER TABLE IF EXISTS public.cuota ALTER COLUMN id_cuota DROP DEFAULT;
ALTER TABLE IF EXISTS public.contrato ALTER COLUMN id_contrato DROP DEFAULT;
ALTER TABLE IF EXISTS public.cliente ALTER COLUMN id_cliente DROP DEFAULT;
ALTER TABLE IF EXISTS public.caracteristica ALTER COLUMN id_caracteristica DROP DEFAULT;
ALTER TABLE IF EXISTS public.bitacora ALTER COLUMN id_bitacora DROP DEFAULT;
ALTER TABLE IF EXISTS public.agente ALTER COLUMN id_agente DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.visita_id_visita_seq;
DROP TABLE IF EXISTS public.visita;
DROP TABLE IF EXISTS public.usuario_sucursal;
DROP TABLE IF EXISTS public.usuario;
DROP SEQUENCE IF EXISTS public.tenant_id_tenant_seq;
DROP TABLE IF EXISTS public.tenant;
DROP TABLE IF EXISTS public.suscripcion_saas;
DROP SEQUENCE IF EXISTS public.sucursal_id_sucursal_seq;
DROP TABLE IF EXISTS public.sucursal;
DROP TABLE IF EXISTS public.rol_permiso;
DROP SEQUENCE IF EXISTS public.rol_id_rol_seq;
DROP TABLE IF EXISTS public.rol;
DROP SEQUENCE IF EXISTS public.reporte_guardado_id_reporte_seq;
DROP TABLE IF EXISTS public.reporte_guardado;
DROP SEQUENCE IF EXISTS public.propietario_id_propietario_seq;
DROP TABLE IF EXISTS public.propietario;
DROP SEQUENCE IF EXISTS public.propiedad_id_propiedad_seq;
DROP TABLE IF EXISTS public.propiedad;
DROP TABLE IF EXISTS public.plan_saas;
DROP SEQUENCE IF EXISTS public.permiso_id_permiso_seq;
DROP TABLE IF EXISTS public.permiso;
DROP SEQUENCE IF EXISTS public.pago_id_pago_seq;
DROP TABLE IF EXISTS public.pago;
DROP SEQUENCE IF EXISTS public.operacion_offline_id_seq;
DROP TABLE IF EXISTS public.operacion_offline;
DROP SEQUENCE IF EXISTS public.imagen_id_imagen_seq;
DROP TABLE IF EXISTS public.imagen;
DROP SEQUENCE IF EXISTS public.cuota_id_cuota_seq;
DROP TABLE IF EXISTS public.cuota;
DROP SEQUENCE IF EXISTS public.contrato_id_contrato_seq;
DROP TABLE IF EXISTS public.contrato;
DROP SEQUENCE IF EXISTS public.cliente_id_cliente_seq;
DROP TABLE IF EXISTS public.cliente;
DROP SEQUENCE IF EXISTS public.caracteristica_id_caracteristica_seq;
DROP TABLE IF EXISTS public.caracteristica;
DROP SEQUENCE IF EXISTS public.bitacora_id_bitacora_seq;
DROP TABLE IF EXISTS public.bitacora;
DROP SEQUENCE IF EXISTS public.agente_id_agente_seq;
DROP TABLE IF EXISTS public.agente;
-- *not* dropping schema, since initdb creates it
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agente (
    id_agente integer NOT NULL,
    ci_usuario character varying(20) NOT NULL,
    id_tenant integer NOT NULL
);


--
-- Name: agente_id_agente_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agente_id_agente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agente_id_agente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agente_id_agente_seq OWNED BY public.agente.id_agente;


--
-- Name: bitacora; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bitacora (
    id_bitacora integer NOT NULL,
    ci_usuario character varying(20) NOT NULL,
    accion character varying(255) NOT NULL,
    fecha_hora timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: bitacora_id_bitacora_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bitacora_id_bitacora_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bitacora_id_bitacora_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bitacora_id_bitacora_seq OWNED BY public.bitacora.id_bitacora;


--
-- Name: caracteristica; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.caracteristica (
    id_caracteristica integer NOT NULL,
    id_propiedad integer NOT NULL,
    nombre character varying(100) NOT NULL,
    valor character varying(100) NOT NULL
);


--
-- Name: caracteristica_id_caracteristica_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.caracteristica_id_caracteristica_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: caracteristica_id_caracteristica_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.caracteristica_id_caracteristica_seq OWNED BY public.caracteristica.id_caracteristica;


--
-- Name: cliente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cliente (
    id_cliente integer NOT NULL,
    ci_usuario character varying(20) NOT NULL,
    id_tenant integer NOT NULL
);


--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cliente_id_cliente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cliente_id_cliente_seq OWNED BY public.cliente.id_cliente;


--
-- Name: contrato; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contrato (
    id_contrato integer NOT NULL,
    id_tenant integer NOT NULL,
    id_cliente integer NOT NULL,
    id_propiedad integer NOT NULL,
    id_agente integer NOT NULL,
    tipo_contrato character varying(50) NOT NULL,
    monto_total numeric(12,2) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date
);


--
-- Name: contrato_id_contrato_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contrato_id_contrato_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contrato_id_contrato_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contrato_id_contrato_seq OWNED BY public.contrato.id_contrato;


--
-- Name: cuota; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cuota (
    id_cuota integer NOT NULL,
    id_contrato integer NOT NULL,
    numero_cuota integer NOT NULL,
    monto numeric(12,2) NOT NULL,
    fecha_vencimiento date NOT NULL,
    estado character varying(20),
    fecha_pago timestamp without time zone
);


--
-- Name: cuota_id_cuota_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cuota_id_cuota_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cuota_id_cuota_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cuota_id_cuota_seq OWNED BY public.cuota.id_cuota;


--
-- Name: imagen; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imagen (
    id_imagen integer NOT NULL,
    id_propiedad integer NOT NULL,
    url character varying(255) NOT NULL
);


--
-- Name: imagen_id_imagen_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.imagen_id_imagen_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: imagen_id_imagen_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.imagen_id_imagen_seq OWNED BY public.imagen.id_imagen;


--
-- Name: operacion_offline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operacion_offline (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    id_tenant integer NOT NULL,
    id_sucursal integer NOT NULL,
    ci_usuario character varying(20) NOT NULL,
    id_cliente integer NOT NULL,
    id_propiedad integer NOT NULL,
    tipo character varying(30) NOT NULL,
    payload_hash character varying(64) NOT NULL,
    datos json NOT NULL,
    estado character varying(20) NOT NULL,
    motivo character varying(255),
    id_contrato integer,
    registrado_en timestamp with time zone NOT NULL,
    procesado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: operacion_offline_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operacion_offline_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operacion_offline_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operacion_offline_id_seq OWNED BY public.operacion_offline.id;


--
-- Name: pago; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pago (
    id_pago integer NOT NULL,
    id_contrato integer NOT NULL,
    monto numeric(12,2) NOT NULL,
    fecha_pago timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metodo_pago character varying(50) NOT NULL,
    numero_recibo character varying(50)
);


--
-- Name: pago_id_pago_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pago_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pago_id_pago_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pago_id_pago_seq OWNED BY public.pago.id_pago;


--
-- Name: permiso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permiso (
    id_permiso integer NOT NULL,
    codigo character varying(50) NOT NULL,
    descripcion character varying(255),
    tipo character varying(50) NOT NULL
);


--
-- Name: permiso_id_permiso_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permiso_id_permiso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permiso_id_permiso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permiso_id_permiso_seq OWNED BY public.permiso.id_permiso;


--
-- Name: plan_saas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_saas (
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    max_sucursales integer NOT NULL,
    reportes_ia boolean NOT NULL,
    CONSTRAINT plan_saas_max_sucursales_check CHECK ((max_sucursales > 0))
);


--
-- Name: propiedad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.propiedad (
    id_propiedad integer NOT NULL,
    id_tenant integer NOT NULL,
    id_propietario integer NOT NULL,
    id_agente integer NOT NULL,
    titulo character varying(150) NOT NULL,
    descripcion character varying(1000),
    direccion character varying(255) NOT NULL,
    precio numeric(12,2) NOT NULL,
    tipo_operacion character varying(20) NOT NULL,
    estado character varying(20),
    version integer DEFAULT 1 NOT NULL,
    id_sucursal integer
);


--
-- Name: propiedad_id_propiedad_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.propiedad_id_propiedad_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: propiedad_id_propiedad_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.propiedad_id_propiedad_seq OWNED BY public.propiedad.id_propiedad;


--
-- Name: propietario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.propietario (
    id_propietario integer NOT NULL,
    ci_usuario character varying(20) NOT NULL,
    id_tenant integer NOT NULL
);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.propietario_id_propietario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.propietario_id_propietario_seq OWNED BY public.propietario.id_propietario;


--
-- Name: reporte_guardado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reporte_guardado (
    id_reporte integer NOT NULL,
    id_tenant integer NOT NULL,
    ci_usuario character varying(20) NOT NULL,
    nombre character varying(150) NOT NULL,
    configuracion text NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: reporte_guardado_id_reporte_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reporte_guardado_id_reporte_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reporte_guardado_id_reporte_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reporte_guardado_id_reporte_seq OWNED BY public.reporte_guardado.id_reporte;


--
-- Name: rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rol (
    id_rol integer NOT NULL,
    id_tenant integer,
    nombre character varying(50) NOT NULL
);


--
-- Name: rol_id_rol_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rol_id_rol_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rol_id_rol_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rol_id_rol_seq OWNED BY public.rol.id_rol;


--
-- Name: rol_permiso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rol_permiso (
    id_rol integer NOT NULL,
    id_permiso integer NOT NULL
);


--
-- Name: sucursal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sucursal (
    id_sucursal integer NOT NULL,
    id_tenant integer NOT NULL,
    nombre character varying(100) NOT NULL,
    direccion character varying(255) NOT NULL,
    activa boolean NOT NULL
);


--
-- Name: sucursal_id_sucursal_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sucursal_id_sucursal_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sucursal_id_sucursal_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sucursal_id_sucursal_seq OWNED BY public.sucursal.id_sucursal;


--
-- Name: suscripcion_saas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suscripcion_saas (
    id_tenant integer NOT NULL,
    codigo_plan character varying(30) NOT NULL,
    inicio date NOT NULL,
    vencimiento date NOT NULL,
    estado character varying(20) NOT NULL
);


--
-- Name: tenant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant (
    id_tenant integer NOT NULL,
    nombre character varying(150) NOT NULL,
    slug character varying(100) NOT NULL,
    plan character varying(50) NOT NULL,
    max_propiedades integer NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    estado boolean,
    fecha_vencimiento_pago date
);


--
-- Name: tenant_id_tenant_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tenant_id_tenant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tenant_id_tenant_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tenant_id_tenant_seq OWNED BY public.tenant.id_tenant;


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario (
    ci character varying(20) NOT NULL,
    id_tenant integer,
    nombre character varying(100) NOT NULL,
    correo character varying(100) NOT NULL,
    telefono character varying(20),
    id_rol integer,
    password_hash character varying(255) NOT NULL
);


--
-- Name: usuario_sucursal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario_sucursal (
    ci_usuario character varying(20) NOT NULL,
    id_sucursal integer NOT NULL
);


--
-- Name: visita; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visita (
    id_visita integer NOT NULL,
    id_tenant integer NOT NULL,
    id_cliente integer NOT NULL,
    id_propiedad integer NOT NULL,
    id_agente integer NOT NULL,
    fecha_hora timestamp without time zone NOT NULL,
    comentario text,
    estado character varying(20)
);


--
-- Name: visita_id_visita_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visita_id_visita_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visita_id_visita_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visita_id_visita_seq OWNED BY public.visita.id_visita;


--
-- Name: agente id_agente; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agente ALTER COLUMN id_agente SET DEFAULT nextval('public.agente_id_agente_seq'::regclass);


--
-- Name: bitacora id_bitacora; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitacora ALTER COLUMN id_bitacora SET DEFAULT nextval('public.bitacora_id_bitacora_seq'::regclass);


--
-- Name: caracteristica id_caracteristica; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caracteristica ALTER COLUMN id_caracteristica SET DEFAULT nextval('public.caracteristica_id_caracteristica_seq'::regclass);


--
-- Name: cliente id_cliente; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente ALTER COLUMN id_cliente SET DEFAULT nextval('public.cliente_id_cliente_seq'::regclass);


--
-- Name: contrato id_contrato; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contrato ALTER COLUMN id_contrato SET DEFAULT nextval('public.contrato_id_contrato_seq'::regclass);


--
-- Name: cuota id_cuota; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuota ALTER COLUMN id_cuota SET DEFAULT nextval('public.cuota_id_cuota_seq'::regclass);


--
-- Name: imagen id_imagen; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagen ALTER COLUMN id_imagen SET DEFAULT nextval('public.imagen_id_imagen_seq'::regclass);


--
-- Name: operacion_offline id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline ALTER COLUMN id SET DEFAULT nextval('public.operacion_offline_id_seq'::regclass);


--
-- Name: pago id_pago; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago ALTER COLUMN id_pago SET DEFAULT nextval('public.pago_id_pago_seq'::regclass);


--
-- Name: permiso id_permiso; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso ALTER COLUMN id_permiso SET DEFAULT nextval('public.permiso_id_permiso_seq'::regclass);


--
-- Name: propiedad id_propiedad; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propiedad ALTER COLUMN id_propiedad SET DEFAULT nextval('public.propiedad_id_propiedad_seq'::regclass);


--
-- Name: propietario id_propietario; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario ALTER COLUMN id_propietario SET DEFAULT nextval('public.propietario_id_propietario_seq'::regclass);


--
-- Name: reporte_guardado id_reporte; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reporte_guardado ALTER COLUMN id_reporte SET DEFAULT nextval('public.reporte_guardado_id_reporte_seq'::regclass);


--
-- Name: rol id_rol; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol ALTER COLUMN id_rol SET DEFAULT nextval('public.rol_id_rol_seq'::regclass);


--
-- Name: sucursal id_sucursal; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sucursal ALTER COLUMN id_sucursal SET DEFAULT nextval('public.sucursal_id_sucursal_seq'::regclass);


--
-- Name: tenant id_tenant; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant ALTER COLUMN id_tenant SET DEFAULT nextval('public.tenant_id_tenant_seq'::regclass);


--
-- Name: visita id_visita; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visita ALTER COLUMN id_visita SET DEFAULT nextval('public.visita_id_visita_seq'::regclass);


--
-- Data for Name: agente; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.agente (id_agente, ci_usuario, id_tenant) FROM stdin;
1	1000002	1
\.


--
-- Data for Name: bitacora; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bitacora (id_bitacora, ci_usuario, accion, fecha_hora) FROM stdin;
\.


--
-- Data for Name: caracteristica; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.caracteristica (id_caracteristica, id_propiedad, nombre, valor) FROM stdin;
1	1	Cuartos	4
2	1	Baños	3
3	1	Metros Cuadrados	350
4	2	Cuartos	2
5	2	Baños	2
6	2	Metros Cuadrados	120
\.


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cliente (id_cliente, ci_usuario, id_tenant) FROM stdin;
1	1000004	1
2	1000005	1
3	1000006	1
\.


--
-- Data for Name: contrato; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.contrato (id_contrato, id_tenant, id_cliente, id_propiedad, id_agente, tipo_contrato, monto_total, fecha_inicio, fecha_fin) FROM stdin;
1	1	1	1	1	Alquiler	1000.00	2026-10-06	\N
\.


--
-- Data for Name: cuota; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cuota (id_cuota, id_contrato, numero_cuota, monto, fecha_vencimiento, estado, fecha_pago) FROM stdin;
1	1	1	1000.00	2026-11-05	Pagada	2026-10-06 21:41:03.13393
\.


--
-- Data for Name: imagen; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.imagen (id_imagen, id_propiedad, url) FROM stdin;
1	1	https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800
2	1	https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800
3	2	https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800
4	3	https://images.unsplash.com/photo-1497366216548-37526070297c?w=800
\.


--
-- Data for Name: operacion_offline; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.operacion_offline (id, uuid, id_tenant, id_sucursal, ci_usuario, id_cliente, id_propiedad, tipo, payload_hash, datos, estado, motivo, id_contrato, registrado_en, procesado_en) FROM stdin;
\.


--
-- Data for Name: pago; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pago (id_pago, id_contrato, monto, fecha_pago, metodo_pago, numero_recibo) FROM stdin;
1	1	1000.00	2026-10-06 21:41:03.123777	Transferencia	REC-1-1
\.


--
-- Data for Name: permiso; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.permiso (id_permiso, codigo, descripcion, tipo) FROM stdin;
1	UI:MENU_CATALOGO	Ver menú de catálogo de propiedades	UI_Menu
2	UI:BTN_CREAR_PROP	Botón para crear una nueva propiedad	UI_Boton
3	UI:BTN_ELIMINAR_PROP	Botón para eliminar propiedad	UI_Boton
4	API:USUARIOS_CREAR	Permiso para crear usuarios	Endpoint
5	UI:MENU_USUARIOS	Ver menú de usuarios	UI_Menu
6	UI:MENU_ROLES	Ver menú de roles	UI_Menu
7	UI:MENU_CLIENTES	Ver menú de clientes	UI_Menu
8	UI:MENU_PROPIETARIOS	Ver menú de propietarios	UI_Menu
9	UI:MENU_AGENTES	Ver menú de agentes	UI_Menu
10	UI:MENU_PROPIEDADES	Ver menú de propiedades	UI_Menu
11	UI:MENU_BITACORA	Ver menú de bitacora segura	UI_Menu
12	UI:MENU_EMPRESAS	Ver menú de empresas	UI_Menu
\.


--
-- Data for Name: plan_saas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.plan_saas (codigo, nombre, max_sucursales, reportes_ia) FROM stdin;
basico	Básico	2	f
profesional	Profesional	10	t
\.


--
-- Data for Name: propiedad; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.propiedad (id_propiedad, id_tenant, id_propietario, id_agente, titulo, descripcion, direccion, precio, tipo_operacion, estado, version, id_sucursal) FROM stdin;
2	1	1	1	Departamento de Lujo en Urubo	Amplio departamento amoblado con vista al golf.	Condominio Urubo Golf	1200.00	Alquiler	Disponible	1	1
3	1	1	1	Local Comercial Centro	Local comercial en pleno centro.	Calle 24 de Septiembre	30000.00	Anticretico	Disponible	1	1
1	1	1	1	Hermosa Casa en Equipetrol	Casa moderna de dos plantas con piscina.	Av. San Martin, 3er Anillo Interno	250000.00	Venta	Disponible	1	1
\.


--
-- Data for Name: propietario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.propietario (id_propietario, ci_usuario, id_tenant) FROM stdin;
1	1000003	1
\.


--
-- Data for Name: reporte_guardado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reporte_guardado (id_reporte, id_tenant, ci_usuario, nombre, configuracion, fecha_creacion) FROM stdin;
\.


--
-- Data for Name: rol; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rol (id_rol, id_tenant, nombre) FROM stdin;
1	\N	Super Administrador
2	\N	Administrador de Empresa
3	1	Agente Raíces
4	1	Cliente Raíces
\.


--
-- Data for Name: rol_permiso; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rol_permiso (id_rol, id_permiso) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
1	7
1	8
1	9
1	10
1	11
1	12
2	1
2	2
2	3
2	4
2	5
2	6
2	7
2	8
2	9
2	10
3	1
3	2
3	7
3	8
3	9
3	10
\.


--
-- Data for Name: sucursal; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sucursal (id_sucursal, id_tenant, nombre, direccion, activa) FROM stdin;
1	1	Casa matriz		t
2	2	Casa matriz		t
3	3	Casa matriz		t
\.


--
-- Data for Name: suscripcion_saas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.suscripcion_saas (id_tenant, codigo_plan, inicio, vencimiento, estado) FROM stdin;
1	profesional	2026-10-30	2026-11-29	activa
2	basico	2026-10-30	2026-11-29	activa
3	basico	2026-10-30	2026-11-29	activa
\.


--
-- Data for Name: tenant; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tenant (id_tenant, nombre, slug, plan, max_propiedades, fecha_registro, estado, fecha_vencimiento_pago) FROM stdin;
1	Raíces Inmobiliaria	raices	pro	50	2026-10-04 21:23:59.264403	t	\N
2	Horizonte Bienes Raíces	horizonte	basico	10	2026-10-04 21:23:59.264403	t	\N
3	Cúspide Propiedades	cuspide	basico	10	2026-10-04 21:23:59.264403	t	\N
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usuario (ci, id_tenant, nombre, correo, telefono, id_rol, password_hash) FROM stdin;
0000000	\N	Super Admin	super@saas.com	70000000	1	$2b$12$eKTs9gea69Z0iXhKD9gbNu3ZUk1BTgSkfw5WuToRCTh/oxembDlei
1000001	1	Admin Raices	admin@raices.com	77712345	2	$2b$12$CCTmb3SSmYmyfQaups0fpOFklvNcDc8.je7WaIKmjp4DOGToVurk.
1000002	1	Ana Agente	agente@raices.com	70000001	3	$2b$12$vvLjBAmu/zNHfOgWHzB5iew6EhoDNPAdR7.yaIu3lvk/lh7e.WqLS
1000003	1	Pablo Propietario	propietario@raices.com	70000002	4	$2b$12$XDgunwa7KfVM7v3IgL3AxOTc0w59U2YqZG5XEPlllaT6jyQdKVmba
1000004	1	Carlos Cliente	cliente@raices.com	70000003	4	$2b$12$A2lIMvXPEHDIOWOC7TAxSORBXJwWYAXWVY5Pf4HmbXnwU37uA/vUC
1000005	1	Rosa Cliente	rosa@raices.com	70000004	4	$2b$12$ipg8G63r4gCziCGsFDwSVOoAFRgvQzar8ea1TrASLGvVl89bAjZt6
1000006	1	Juan Cliente	juan@raices.com	70000005	4	$2b$12$u3XvNlUVb3N1s2sxuZL.VeDZ8IUtl/f3KiKRGQP6TflgVAkHeYoey
\.


--
-- Data for Name: usuario_sucursal; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usuario_sucursal (ci_usuario, id_sucursal) FROM stdin;
1000002	1
\.


--
-- Data for Name: visita; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.visita (id_visita, id_tenant, id_cliente, id_propiedad, id_agente, fecha_hora, comentario, estado) FROM stdin;
\.


--
-- Name: agente_id_agente_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.agente_id_agente_seq', 1, true);


--
-- Name: bitacora_id_bitacora_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bitacora_id_bitacora_seq', 1, false);


--
-- Name: caracteristica_id_caracteristica_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.caracteristica_id_caracteristica_seq', 6, true);


--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cliente_id_cliente_seq', 3, true);


--
-- Name: contrato_id_contrato_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.contrato_id_contrato_seq', 1, true);


--
-- Name: cuota_id_cuota_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cuota_id_cuota_seq', 1, true);


--
-- Name: imagen_id_imagen_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.imagen_id_imagen_seq', 4, true);


--
-- Name: operacion_offline_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.operacion_offline_id_seq', 1, false);


--
-- Name: pago_id_pago_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pago_id_pago_seq', 1, true);


--
-- Name: permiso_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.permiso_id_permiso_seq', 12, true);


--
-- Name: propiedad_id_propiedad_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.propiedad_id_propiedad_seq', 3, true);


--
-- Name: propietario_id_propietario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 1, true);


--
-- Name: reporte_guardado_id_reporte_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.reporte_guardado_id_reporte_seq', 1, false);


--
-- Name: rol_id_rol_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rol_id_rol_seq', 4, true);


--
-- Name: sucursal_id_sucursal_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sucursal_id_sucursal_seq', 3, true);


--
-- Name: tenant_id_tenant_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tenant_id_tenant_seq', 3, true);


--
-- Name: visita_id_visita_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.visita_id_visita_seq', 1, false);


--
-- Name: agente agente_ci_usuario_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agente
    ADD CONSTRAINT agente_ci_usuario_key UNIQUE (ci_usuario);


--
-- Name: agente agente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agente
    ADD CONSTRAINT agente_pkey PRIMARY KEY (id_agente);


--
-- Name: bitacora bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_pkey PRIMARY KEY (id_bitacora);


--
-- Name: caracteristica caracteristica_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caracteristica
    ADD CONSTRAINT caracteristica_pkey PRIMARY KEY (id_caracteristica);


--
-- Name: cliente cliente_ci_usuario_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_ci_usuario_key UNIQUE (ci_usuario);


--
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id_cliente);


--
-- Name: contrato contrato_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT contrato_pkey PRIMARY KEY (id_contrato);


--
-- Name: cuota cuota_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuota
    ADD CONSTRAINT cuota_pkey PRIMARY KEY (id_cuota);


--
-- Name: imagen imagen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagen
    ADD CONSTRAINT imagen_pkey PRIMARY KEY (id_imagen);


--
-- Name: operacion_offline operacion_offline_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_pkey PRIMARY KEY (id);


--
-- Name: pago pago_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_pkey PRIMARY KEY (id_pago);


--
-- Name: permiso permiso_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso
    ADD CONSTRAINT permiso_codigo_key UNIQUE (codigo);


--
-- Name: permiso permiso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permiso
    ADD CONSTRAINT permiso_pkey PRIMARY KEY (id_permiso);


--
-- Name: plan_saas plan_saas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_saas
    ADD CONSTRAINT plan_saas_pkey PRIMARY KEY (codigo);


--
-- Name: propiedad propiedad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propiedad
    ADD CONSTRAINT propiedad_pkey PRIMARY KEY (id_propiedad);


--
-- Name: propietario propietario_ci_usuario_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_ci_usuario_key UNIQUE (ci_usuario);


--
-- Name: propietario propietario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_pkey PRIMARY KEY (id_propietario);


--
-- Name: reporte_guardado reporte_guardado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reporte_guardado
    ADD CONSTRAINT reporte_guardado_pkey PRIMARY KEY (id_reporte);


--
-- Name: rol_permiso rol_permiso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_pkey PRIMARY KEY (id_rol, id_permiso);


--
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id_rol);


--
-- Name: sucursal sucursal_id_tenant_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sucursal
    ADD CONSTRAINT sucursal_id_tenant_nombre_key UNIQUE (id_tenant, nombre);


--
-- Name: sucursal sucursal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sucursal
    ADD CONSTRAINT sucursal_pkey PRIMARY KEY (id_sucursal);


--
-- Name: suscripcion_saas suscripcion_saas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suscripcion_saas
    ADD CONSTRAINT suscripcion_saas_pkey PRIMARY KEY (id_tenant);


--
-- Name: tenant tenant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant
    ADD CONSTRAINT tenant_pkey PRIMARY KEY (id_tenant);


--
-- Name: operacion_offline uq_offline_tenant_uuid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT uq_offline_tenant_uuid UNIQUE (id_tenant, uuid);


--
-- Name: usuario uq_usuario_tenant_ci; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT uq_usuario_tenant_ci UNIQUE (id_tenant, ci);


--
-- Name: usuario uq_usuario_tenant_correo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT uq_usuario_tenant_correo UNIQUE (id_tenant, correo);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (ci);


--
-- Name: usuario_sucursal usuario_sucursal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sucursal
    ADD CONSTRAINT usuario_sucursal_pkey PRIMARY KEY (ci_usuario, id_sucursal);


--
-- Name: visita visita_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visita
    ADD CONSTRAINT visita_pkey PRIMARY KEY (id_visita);


--
-- Name: ix_agente_id_agente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_agente_id_agente ON public.agente USING btree (id_agente);


--
-- Name: ix_bitacora_id_bitacora; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bitacora_id_bitacora ON public.bitacora USING btree (id_bitacora);


--
-- Name: ix_caracteristica_id_caracteristica; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_caracteristica_id_caracteristica ON public.caracteristica USING btree (id_caracteristica);


--
-- Name: ix_cliente_id_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cliente_id_cliente ON public.cliente USING btree (id_cliente);


--
-- Name: ix_contrato_id_contrato; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contrato_id_contrato ON public.contrato USING btree (id_contrato);


--
-- Name: ix_cuota_id_cuota; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_cuota_id_cuota ON public.cuota USING btree (id_cuota);


--
-- Name: ix_imagen_id_imagen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_imagen_id_imagen ON public.imagen USING btree (id_imagen);


--
-- Name: ix_operacion_offline_id_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_operacion_offline_id_tenant ON public.operacion_offline USING btree (id_tenant);


--
-- Name: ix_pago_id_pago; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pago_id_pago ON public.pago USING btree (id_pago);


--
-- Name: ix_permiso_id_permiso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_permiso_id_permiso ON public.permiso USING btree (id_permiso);


--
-- Name: ix_propiedad_id_propiedad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_propiedad_id_propiedad ON public.propiedad USING btree (id_propiedad);


--
-- Name: ix_propiedad_id_sucursal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_propiedad_id_sucursal ON public.propiedad USING btree (id_sucursal);


--
-- Name: ix_propietario_id_propietario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_propietario_id_propietario ON public.propietario USING btree (id_propietario);


--
-- Name: ix_reporte_guardado_id_reporte; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_reporte_guardado_id_reporte ON public.reporte_guardado USING btree (id_reporte);


--
-- Name: ix_rol_id_rol; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_rol_id_rol ON public.rol USING btree (id_rol);


--
-- Name: ix_sucursal_id_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_sucursal_id_tenant ON public.sucursal USING btree (id_tenant);


--
-- Name: ix_tenant_id_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tenant_id_tenant ON public.tenant USING btree (id_tenant);


--
-- Name: ix_tenant_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_tenant_slug ON public.tenant USING btree (slug);


--
-- Name: ix_usuario_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_usuario_ci ON public.usuario USING btree (ci);


--
-- Name: ix_usuario_correo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_usuario_correo ON public.usuario USING btree (correo);


--
-- Name: ix_visita_id_visita; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_visita_id_visita ON public.visita USING btree (id_visita);


--
-- Name: agente agente_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agente
    ADD CONSTRAINT agente_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: agente agente_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agente
    ADD CONSTRAINT agente_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: bitacora bitacora_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: caracteristica caracteristica_id_propiedad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.caracteristica
    ADD CONSTRAINT caracteristica_id_propiedad_fkey FOREIGN KEY (id_propiedad) REFERENCES public.propiedad(id_propiedad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cliente cliente_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cliente cliente_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: contrato contrato_id_agente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT contrato_id_agente_fkey FOREIGN KEY (id_agente) REFERENCES public.agente(id_agente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: contrato contrato_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT contrato_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: contrato contrato_id_propiedad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT contrato_id_propiedad_fkey FOREIGN KEY (id_propiedad) REFERENCES public.propiedad(id_propiedad) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: contrato contrato_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contrato
    ADD CONSTRAINT contrato_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cuota cuota_id_contrato_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuota
    ADD CONSTRAINT cuota_id_contrato_fkey FOREIGN KEY (id_contrato) REFERENCES public.contrato(id_contrato) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: imagen imagen_id_propiedad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagen
    ADD CONSTRAINT imagen_id_propiedad_fkey FOREIGN KEY (id_propiedad) REFERENCES public.propiedad(id_propiedad) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: operacion_offline operacion_offline_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci);


--
-- Name: operacion_offline operacion_offline_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente);


--
-- Name: operacion_offline operacion_offline_id_contrato_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_id_contrato_fkey FOREIGN KEY (id_contrato) REFERENCES public.contrato(id_contrato);


--
-- Name: operacion_offline operacion_offline_id_propiedad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_id_propiedad_fkey FOREIGN KEY (id_propiedad) REFERENCES public.propiedad(id_propiedad);


--
-- Name: operacion_offline operacion_offline_id_sucursal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.sucursal(id_sucursal);


--
-- Name: operacion_offline operacion_offline_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operacion_offline
    ADD CONSTRAINT operacion_offline_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant);


--
-- Name: pago pago_id_contrato_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_id_contrato_fkey FOREIGN KEY (id_contrato) REFERENCES public.contrato(id_contrato) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: propiedad propiedad_id_agente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propiedad
    ADD CONSTRAINT propiedad_id_agente_fkey FOREIGN KEY (id_agente) REFERENCES public.agente(id_agente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: propiedad propiedad_id_propietario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propiedad
    ADD CONSTRAINT propiedad_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: propiedad propiedad_id_sucursal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propiedad
    ADD CONSTRAINT propiedad_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.sucursal(id_sucursal);


--
-- Name: propiedad propiedad_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propiedad
    ADD CONSTRAINT propiedad_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: propietario propietario_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: propietario propietario_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: reporte_guardado reporte_guardado_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reporte_guardado
    ADD CONSTRAINT reporte_guardado_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: reporte_guardado reporte_guardado_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reporte_guardado
    ADD CONSTRAINT reporte_guardado_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rol rol_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rol_permiso rol_permiso_id_permiso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_id_permiso_fkey FOREIGN KEY (id_permiso) REFERENCES public.permiso(id_permiso) ON DELETE CASCADE;


--
-- Name: rol_permiso rol_permiso_id_rol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.rol(id_rol) ON DELETE CASCADE;


--
-- Name: sucursal sucursal_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sucursal
    ADD CONSTRAINT sucursal_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant);


--
-- Name: suscripcion_saas suscripcion_saas_codigo_plan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suscripcion_saas
    ADD CONSTRAINT suscripcion_saas_codigo_plan_fkey FOREIGN KEY (codigo_plan) REFERENCES public.plan_saas(codigo);


--
-- Name: suscripcion_saas suscripcion_saas_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suscripcion_saas
    ADD CONSTRAINT suscripcion_saas_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant);


--
-- Name: usuario usuario_id_rol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.rol(id_rol);


--
-- Name: usuario usuario_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: usuario_sucursal usuario_sucursal_ci_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sucursal
    ADD CONSTRAINT usuario_sucursal_ci_usuario_fkey FOREIGN KEY (ci_usuario) REFERENCES public.usuario(ci);


--
-- Name: usuario_sucursal usuario_sucursal_id_sucursal_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sucursal
    ADD CONSTRAINT usuario_sucursal_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.sucursal(id_sucursal);


--
-- Name: visita visita_id_agente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visita
    ADD CONSTRAINT visita_id_agente_fkey FOREIGN KEY (id_agente) REFERENCES public.agente(id_agente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: visita visita_id_cliente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visita
    ADD CONSTRAINT visita_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: visita visita_id_propiedad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visita
    ADD CONSTRAINT visita_id_propiedad_fkey FOREIGN KEY (id_propiedad) REFERENCES public.propiedad(id_propiedad) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: visita visita_id_tenant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visita
    ADD CONSTRAINT visita_id_tenant_fkey FOREIGN KEY (id_tenant) REFERENCES public.tenant(id_tenant) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES TO raices;


--
-- Name: DEFAULT PRIVILEGES FOR TYPES; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TYPES TO raices;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS TO raices;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO raices;


--
-- PostgreSQL database dump complete
--

\unrestrict sUDV8mGcGoYNQjgbpH2F0B3mn7rhP8kJc2SA8Lx6uxPEEH3glSwASwRO9qltqPs

