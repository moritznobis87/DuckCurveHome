/**
 * Das Haus als Glasmodell in Kavalierprojektion.
 *
 * **Was hier gezeichnet wird, steht im Plan.** Decks, Raeume, Waende, Fenster, Kontakte, Moebel
 * und Geraete kommen aus `HousePlan`; diese Datei kennt nur die Bausteine und ihre Sprache. Der
 * Grundriss bleibt massstaeblich und rechtwinklig, senkrechte Kanten laufen schraeg nach rechts
 * oben, damit Waende und Moebel zwei Seiten zeigen. Gedreht wird in Viertelschritten.
 *
 * **Was lebt, kommt aus `HausLive`.** Boeden leuchten in der Raumtemperatur, offene Heizkreise
 * zeigen ihre Schleifen, Tueren und Fenster mit Kontakt gehen auf, der Schutzschild der
 * Alarmanlage steht um die Aussenhaut, Puffer, Waermepumpe und Wallbox zeigen ihre Zahlen.
 *
 * Kein React in dieser Datei: three.js verwaltet seine Objekte selbst, und die Beschriftungen
 * haengen als DOM-Knoten an einem zweiten Renderer, der sie Bild fuer Bild mitfuehrt.
 */
import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { CSS2DObject, CSS2DRenderer } from "three/addons/renderers/CSS2DRenderer.js";
import type { HouseContactPlan, HouseDeck, HouseItem, HouseOpening, HousePlan, HouseRoom } from "@/lib/api/models";
import { K_X, K_Y, bildschirm, strahl, tempFarbe, umgrenzung, versetzt, wandlinie, wandstuecke } from "./geometrie";
import type { AlarmStufe, HausLive } from "./live";

export interface FokusInfo {
  deck: string;
  raum: HouseRoom;
}

export interface SzeneOptionen {
  root: HTMLElement;
  plan: HousePlan;
  onFokus: (f: FokusInfo | null) => void;
  /** Anfangszustand, etwa aus der Adresse. */
  start?: { sichtbar?: string; drehung?: number; fokus?: string };
}

// ------------------------------------------------------------------ Masse und Farben
const WAND_H = 1.0;
const AUSSEN_H = 1.15;
const BODEN_D = 0.14;
const KANTE = 0xbfeeff;
const AMBER = 0xf2b134;
const ORANGE = 0xff7a45;
const ROT = 0xff3b3b;
const HIMMEL = 0x0b2e3f;
const TELEFON_BREITE = 720;

const de = (n: number, d = 1) => n.toLocaleString("de-DE", { minimumFractionDigits: d, maximumFractionDigits: d });

const glas = (color: number, opacity: number, extra: THREE.MeshLambertMaterialParameters = {}) =>
  new THREE.MeshLambertMaterial({ color, transparent: true, opacity, depthWrite: false, ...extra });

type Ton = NonNullable<HouseItem["tone"]>;

// ------------------------------------------------------------------ Auto: ein Koerper aus Querschnitten
// Leitpunkte von der Nase zum Heck: x, halbe Breite, Guertellinie, Hoehe. Dazwischen glatt.
const AUTO_LEIT: [number, number, number, number][] = [
  [2.42, 0.1, 0.5, 0.54], [2.38, 0.42, 0.56, 0.62], [2.3, 0.66, 0.64, 0.7], [2.05, 0.82, 0.69, 0.78],
  [1.6, 0.91, 0.71, 0.84], [1.1, 0.94, 0.73, 0.89], [0.6, 0.95, 0.74, 0.94], [0.2, 0.95, 0.75, 1.16],
  [-0.2, 0.95, 0.76, 1.34], [-0.6, 0.95, 0.77, 1.4], [-1.0, 0.95, 0.78, 1.38], [-1.4, 0.96, 0.79, 1.26],
  [-1.8, 0.95, 0.8, 1.08], [-2.1, 0.9, 0.81, 0.96], [-2.28, 0.78, 0.8, 0.93], [-2.38, 0.5, 0.74, 0.86],
  [-2.42, 0.1, 0.62, 0.72],
];
const AUTO_BODEN = 0.2;
function kanal(idx: 1 | 2 | 3): (x: number) => number {
  const kurve = new THREE.CatmullRomCurve3(AUTO_LEIT.map((l) => new THREE.Vector3(l[0], l[idx], 0)), false, "centripetal");
  const pts = kurve.getPoints(400);
  return (x: number) => {
    const erster = pts[0]!;
    if (x >= erster.x) return erster.y;
    for (let i = 1; i < pts.length; i++) {
      const b = pts[i]!;
      if (x >= b.x) {
        const a = pts[i - 1]!;
        return a.y + (b.y - a.y) * ((a.x - x) / (a.x - b.x || 1e-6));
      }
    }
    return pts[pts.length - 1]!.y;
  };
}
const autoBreite = kanal(1);
const autoGuertel = kanal(2);
const autoHoehe = kanal(3);
interface RingInfo { ring: [number, number][]; schulter: number; n: number }
function autoRing(w: number, yb: number, h: number): RingInfo {
  const rb = Math.min(0.1, w * 0.6);
  const tumble = Math.min(Math.max((h - yb) * 0.55, 0.05), w * 0.3);
  const wt = w - tumble;
  const rechts: [number, number][] = [[0, AUTO_BODEN], [w - rb, AUTO_BODEN]];
  for (let i = 1; i <= 3; i++) {
    const a = (i / 3) * Math.PI / 2;
    rechts.push([w - rb + rb * Math.sin(a), AUTO_BODEN + rb - rb * Math.cos(a)]);
  }
  rechts.push([w, (AUTO_BODEN + yb) / 2]);
  const schulter = rechts.length;
  rechts.push([w, yb]);
  for (let i = 1; i <= 7; i++) {
    const t = i / 7;
    const c1 = [w * 0.995, yb + (h - yb) * 0.62];
    rechts.push([(1 - t) * (1 - t) * w + 2 * (1 - t) * t * c1[0]! + t * t * wt, (1 - t) * (1 - t) * yb + 2 * (1 - t) * t * c1[1]! + t * t * h]);
  }
  for (let i = 1; i <= 3; i++) {
    const t = i / 3;
    rechts.push([wt * (1 - t), h + 0.025 * Math.sin(t * Math.PI / 2)]);
  }
  const links = rechts.slice(1, -1).reverse().map(([z, y]) => [-z, y] as [number, number]);
  return { ring: rechts.concat(links), schulter, n: rechts.length };
}
function autoAnteil(info: RingInfo, j: number): number | null {
  const M = info.ring.length;
  const jj = j < info.n ? j : M - j;
  if (jj < info.schulter) return null;
  return (jj - info.schulter) / (info.n - 1 - info.schulter);
}
const autoVorn = (u: number) => (u >= 0.6 ? 0.6 : 0.2 + 0.4 * (u / 0.6));
const autoHinten = (u: number) => (u >= 0.6 ? -2.0 : -1.45 - 0.55 * (u / 0.6));

// ------------------------------------------------------------------ Knoten, die leben
interface RaumKnoten {
  deck: HouseDeck;
  raum: HouseRoom;
  haupt: HouseRoom;
  gruppe: THREE.Group;
  boden: THREE.Mesh | null;
  bodenMat: THREE.MeshLambertMaterial;
  heiz: THREE.Mesh | null;
  heizMat: THREE.MeshBasicMaterial | null;
  label: CSS2DObject | null;
  temp: number | null;
  ventil: number;
}
interface KontaktKnoten {
  k: HouseContactPlan;
  angel: THREE.Group;
  mat: THREE.MeshLambertMaterial;
  streifen: THREE.MeshBasicMaterial;
  label: CSS2DObject;
  winkel: number;
  offen: boolean;
  alarm: boolean;
}
interface Chip { el: HTMLElement; zahl: HTMLElement }
interface Glut { mat: THREE.MeshBasicMaterial; device: string | null }

export class HausSzene {
  private readonly root: HTMLElement;
  private readonly plan: HousePlan;
  private readonly onFokus: (f: FokusInfo | null) => void;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly labels: CSS2DRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -500, 500);
  private readonly composer: EffectComposer;
  private readonly bloom: UnrealBloomPass;
  private readonly key: THREE.DirectionalLight;
  private readonly rim: THREE.DirectionalLight;
  private readonly uhr = new THREE.Clock();
  private readonly beobachter: ResizeObserver;
  private raf = 0;
  private verworfen = false;

  // Materialien, geteilt
  private readonly matWand = glas(0xcfe9f2, 0.16, { side: THREE.DoubleSide });
  private readonly matWandAussen = glas(0xdff2f8, 0.24, { side: THREE.DoubleSide });
  private readonly matKante = new THREE.LineBasicMaterial({ color: KANTE, transparent: true, opacity: 0.5 });
  private readonly matKanteFein = new THREE.LineBasicMaterial({ color: KANTE, transparent: true, opacity: 0.28 });
  private readonly matKanteAmber = new THREE.LineBasicMaterial({ color: AMBER, transparent: true, opacity: 0.4 });
  private readonly matGelaender = new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.75 });
  private readonly toene: Record<Ton, THREE.MeshLambertMaterial> = {
    dark: glas(0x0f3243, 0.66),
    light: glas(0x2f5d70, 0.62),
    soft: glas(0x5f8fa3, 0.55),
    water: glas(0x7fd3e6, 0.5),
    wall: glas(0xdff2f8, 0.24, { side: THREE.DoubleSide }),
    paving: new THREE.MeshLambertMaterial({ color: 0x103647 }),
    terrace: new THREE.MeshLambertMaterial({ color: 0x134052 }),
    slate: glas(0x24323a, 0.75),
  };
  private readonly matStufe = new THREE.MeshLambertMaterial({ color: 0x7fe3ff, emissive: 0x3f9fc0, emissiveIntensity: 0.55, transparent: true, opacity: 0.7, depthWrite: false });
  private readonly matEmpore = glas(0x9fd3e6, 0.22, { side: THREE.DoubleSide });
  private readonly matPlatte = new THREE.MeshLambertMaterial({ color: 0x0b2a3a });
  private readonly matPlatteRand = new THREE.MeshLambertMaterial({ color: 0x15415a });
  private readonly matGrube = new THREE.MeshBasicMaterial({ color: 0x04141c });
  private readonly matGlut = new THREE.MeshBasicMaterial({ color: 0xffa050, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false });
  private readonly matRohr = new THREE.MeshBasicMaterial({ color: 0xe08b4a, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false });
  private readonly matLack = new THREE.MeshPhongMaterial({ color: 0x1a4357, specular: 0x4a8ea6, shininess: 110, transparent: true, opacity: 0.9, side: THREE.FrontSide, depthWrite: false });
  private readonly matScheibe = new THREE.MeshPhongMaterial({ color: 0xa6e4f6, specular: 0xbfe8f5, shininess: 160, transparent: true, opacity: 0.42, side: THREE.DoubleSide, depthWrite: false });
  private readonly matReifen = new THREE.MeshLambertMaterial({ color: 0x061620, transparent: true, opacity: 0.92, depthWrite: false });
  private readonly matFelge = new THREE.MeshBasicMaterial({ color: 0x8fd8ea, transparent: true, opacity: 0.55, depthWrite: false });
  private readonly matLeuchte = new THREE.MeshBasicMaterial({ color: 0xe8fbff, transparent: true, opacity: 0.95, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  private readonly matRuecklicht = new THREE.MeshBasicMaterial({ color: 0xff4a30, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  private readonly matGuertel = new THREE.LineBasicMaterial({ color: KANTE, transparent: true, opacity: 0.35 });
  private readonly texHeiz: THREE.CanvasTexture | null;
  private readonly texFliesen: THREE.CanvasTexture | null;
  private readonly texRaster: THREE.CanvasTexture | null;

  // Szene
  private readonly deckGruppen = new Map<string, THREE.Group>();
  private readonly deckGrenzen = new Map<string, { x0: number; x1: number; z0: number; z1: number; h: number }>();
  private readonly deckNamen: { label: CSS2DObject; ecken: [number, number][] }[] = [];
  private readonly raumKnoten: RaumKnoten[] = [];
  private readonly kontaktKnoten: KontaktKnoten[] = [];
  private readonly schilde: { flaeche: THREE.MeshBasicMaterial; kante: THREE.LineBasicMaterial }[] = [];
  private readonly nurNah: CSS2DObject[] = [];
  private readonly rotoren: THREE.Group[] = [];
  private readonly gluten: Glut[] = [];
  private readonly pufferSchichten: THREE.MeshLambertMaterial[][] = [];
  private readonly chips: { puffer: Chip[]; waermepumpe: Chip[]; wallbox: Chip[] } = { puffer: [], waermepumpe: [], wallbox: [] };

  // Zustand
  private theta = 0;
  private thetaZiel = 0;
  private readonly ansicht = { sxC: 0, suC: 0, W: 40, H: 30 };
  private readonly ansichtZiel = { sxC: 0, suC: 0, W: 40, H: 30 };
  private tiefeMitte = 0;
  private tiefeHalb = 40;
  private telefon = false;
  private sichtbar = "alle";
  private fokus: RaumKnoten | null = null;
  private live: HausLive | null = null;
  private alarm: AlarmStufe = "unbekannt";
  private zeiger: { x: number; y: number; t: number } | null = null;

  constructor(opts: SzeneOptionen) {
    this.root = opts.root;
    this.plan = opts.plan;
    this.onFokus = opts.onFokus;

    this.renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.domElement.className = "haus-canvas";
    this.root.appendChild(this.renderer.domElement);
    this.labels = new CSS2DRenderer();
    this.labels.domElement.className = "haus-labels";
    this.root.appendChild(this.labels.domElement);

    const himmel = new THREE.Mesh(new THREE.SphereGeometry(400, 24, 16), new THREE.MeshBasicMaterial({ color: HIMMEL, side: THREE.BackSide, depthWrite: false }));
    himmel.renderOrder = -10;
    this.scene.add(himmel);
    this.scene.add(new THREE.HemisphereLight(0xbfe6f4, 0x08202c, 1.25));
    this.key = new THREE.DirectionalLight(0xfff3e0, 1.4);
    this.scene.add(this.key, this.key.target);
    this.rim = new THREE.DirectionalLight(0x7fe3ff, 0.6);
    this.scene.add(this.rim, this.rim.target);

    this.camera.matrixAutoUpdate = false;
    this.camera.updateProjectionMatrix = () => this.projektionSetzen();

    this.texHeiz = null;
    this.texFliesen = HausSzene.fliesenTextur();
    this.texRaster = HausSzene.rasterTextur();

    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.55, 0.4, 0.82);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());

    for (const deck of this.plan.decks) this.baueDeck(deck);

    this.labels.domElement.addEventListener("pointerdown", this.aufPointerDown);
    this.labels.domElement.addEventListener("pointerup", this.aufPointerUp);
    this.beobachter = new ResizeObserver(() => this.groesse());
    this.beobachter.observe(this.root);

    const start = opts.start ?? {};
    if (start.drehung) this.theta = this.thetaZiel = (start.drehung * Math.PI) / 2;
    this.telefon = this.root.clientWidth < TELEFON_BREITE;
    this.sichtbar = start.sichtbar && (start.sichtbar === "alle" || this.deckGruppen.has(start.sichtbar)) ? start.sichtbar : this.telefon ? (this.plan.decks[0]?.key ?? "alle") : "alle";
    this.groesse();
    Object.assign(this.ansicht, this.ansichtZiel);
    if (start.fokus) {
      const k = this.raumKnoten.find((r) => r.raum.name === start.fokus && !r.raum.part_of);
      if (k) {
        this.setzeFokusKnoten(k, false);
        Object.assign(this.ansicht, this.ansichtZiel);
      }
    }
    this.takt();
  }

  // ------------------------------------------------------------------ Oeffentliches
  decks(): { key: string; name: string }[] {
    return this.plan.decks.map((d) => ({ key: d.key, name: d.name }));
  }
  get sichtbaresDeck(): string {
    return this.sichtbar;
  }

  setSichtbar(key: string): void {
    this.sichtbar = key;
    if (this.fokus && key !== "alle" && this.fokus.deck.key !== key) this.setzeFokusKnoten(null, true);
    this.ausschnittBerechnen();
  }

  drehen(richtung: -1 | 1): void {
    this.thetaZiel += (richtung * Math.PI) / 2;
    this.ausschnittBerechnen();
  }

  setFokus(deck: string | null, name: string | null): void {
    if (!deck || !name) {
      this.setzeFokusKnoten(null, false);
      return;
    }
    const k = this.raumKnoten.find((r) => r.deck.key === deck && r.raum.name === name && !r.raum.part_of);
    this.setzeFokusKnoten(k ?? null, false);
  }

  setLive(live: HausLive): void {
    this.live = live;
    this.alarm = live.alarm;
    for (const r of this.raumKnoten) {
      const id = r.haupt.room_id;
      const werte = id != null ? live.raeume.get(id) : undefined;
      r.temp = werte?.temp_c ?? null;
      r.ventil = werte?.valve ?? 0;
      this.raumFarbe(r);
      if (r.label && r.raum === r.haupt) {
        const el = r.label.element;
        const zahl = el.querySelector(".t");
        if (zahl) zahl.textContent = r.temp == null ? "-" : `${de(r.temp)}°`;
        const ziel = werte?.target_c ?? werte?.setpoint_c ?? null;
        el.classList.toggle("unter", r.temp != null && ziel != null && r.temp < ziel - 0.3);
        el.classList.toggle("stumm", id != null && r.temp == null);
      }
    }
    for (const kk of this.kontaktKnoten) {
      const z = live.kontakte.get(kk.k.key);
      kk.offen = z?.open === true;
      kk.label.visible = kk.offen;
    }
    this.alarmAnwenden();
    const soc = live.pufferSoc;
    for (const c of this.chips.puffer) c.zahl.textContent = soc == null ? "-" : `${Math.round(soc * 100)} %`;
    for (const c of this.chips.waermepumpe) c.zahl.textContent = live.waermepumpeKw == null ? "-" : `${de(live.waermepumpeKw)} kW`;
    for (const c of this.chips.wallbox) c.zahl.textContent = live.wallboxKw == null ? "-" : `${de(live.wallboxKw)} kW`;
    for (const schichten of this.pufferSchichten) {
      schichten.forEach((m, i) => {
        const t = live.pufferTemps[i];
        const farbe = new THREE.Color(t == null ? 0x2b4a58 : tempFarbe(16 + ((t - 39) / 13) * 10));
        m.color.copy(farbe);
        m.emissive.copy(farbe);
        m.emissiveIntensity = t == null ? 0.05 : 0.45;
      });
    }
  }

  dispose(): void {
    this.verworfen = true;
    cancelAnimationFrame(this.raf);
    this.beobachter.disconnect();
    this.labels.domElement.removeEventListener("pointerdown", this.aufPointerDown);
    this.labels.domElement.removeEventListener("pointerup", this.aufPointerUp);
    this.scene.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.geometry) m.geometry.dispose();
      const mat = (m as THREE.Mesh).material as THREE.Material | THREE.Material[] | undefined;
      if (Array.isArray(mat)) mat.forEach((x) => x.dispose());
      else mat?.dispose();
    });
    this.texFliesen?.dispose();
    this.texRaster?.dispose();
    this.composer.dispose();
    this.renderer.dispose();
    this.renderer.domElement.remove();
    this.labels.domElement.remove();
  }

  // ------------------------------------------------------------------ Texturen
  private static fliesenTextur(): THREE.CanvasTexture | null {
    const n = 128;
    const c = document.createElement("canvas");
    c.width = c.height = n;
    const g = c.getContext("2d");
    if (!g) return null;
    g.clearRect(0, 0, n, n);
    g.fillStyle = "rgba(4,14,22,0.13)";
    g.fillRect(0, 0, n / 2, n / 2);
    g.fillRect(n / 2, n / 2, n / 2, n / 2);
    g.fillStyle = "rgba(255,255,255,0.035)";
    g.fillRect(n / 2, 0, n / 2, n / 2);
    g.fillRect(0, n / 2, n / 2, n / 2);
    const t = new THREE.CanvasTexture(c);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.center.set(0.5, 0.5);
    t.rotation = Math.PI / 4;
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }
  private static rasterTextur(): THREE.CanvasTexture | null {
    const n = 64;
    const c = document.createElement("canvas");
    c.width = c.height = n;
    const g = c.getContext("2d");
    if (!g) return null;
    g.clearRect(0, 0, n, n);
    g.strokeStyle = "rgba(169,236,255,0.9)";
    g.lineWidth = 1;
    g.beginPath();
    g.moveTo(0.5, 0);
    g.lineTo(0.5, n);
    g.moveTo(0, 0.5);
    g.lineTo(n, 0.5);
    g.stroke();
    const t = new THREE.CanvasTexture(c);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }
  /** Heizschleife: Rohrschlangen im Seitenverhaeltnis des Raums. */
  private static schleifenTextur(b: number, t: number): THREE.CanvasTexture | null {
    const px = 48;
    const c = document.createElement("canvas");
    c.width = Math.max(8, Math.min(1024, Math.round(b * px)));
    c.height = Math.max(8, Math.min(1024, Math.round(t * px)));
    const g = c.getContext("2d");
    if (!g) return null;
    g.clearRect(0, 0, c.width, c.height);
    g.strokeStyle = "rgba(255,200,90,1)";
    g.lineWidth = 3;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.shadowColor = "rgba(255,180,60,0.9)";
    g.shadowBlur = 8;
    const rand = px * 0.3;
    const reihen = Math.max(2, Math.round((t - 0.6) / 0.5) + 1);
    const dy = (c.height - 2 * rand) / (reihen - 1);
    g.beginPath();
    for (let r = 0; r < reihen; r++) {
      const y = rand + r * dy;
      if (r % 2 === 0) {
        if (r === 0) g.moveTo(rand, y);
        g.lineTo(c.width - rand, y);
        if (r < reihen - 1) g.lineTo(c.width - rand, y + dy);
      } else {
        g.lineTo(rand, y);
        if (r < reihen - 1) g.lineTo(rand, y + dy);
      }
    }
    g.stroke();
    const tex = new THREE.CanvasTexture(c);
    tex.colorSpace = THREE.SRGBColorSpace;
    return tex;
  }
  private static kontaktSchatten(b: number, t: number): THREE.Mesh {
    const n = 128;
    const c = document.createElement("canvas");
    c.width = c.height = n;
    const g = c.getContext("2d");
    let tex: THREE.CanvasTexture | null = null;
    if (g) {
      const grad = g.createRadialGradient(n / 2, n / 2, n * 0.1, n / 2, n / 2, n / 2);
      grad.addColorStop(0, "rgba(0,0,0,0.6)");
      grad.addColorStop(1, "rgba(0,0,0,0)");
      g.fillStyle = grad;
      g.fillRect(0, 0, n, n);
      tex = new THREE.CanvasTexture(c);
    }
    const m = new THREE.Mesh(new THREE.PlaneGeometry(b, t), new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false, opacity: tex ? 1 : 0 }));
    m.rotation.x = -Math.PI / 2;
    m.position.y = 0.012;
    return m;
  }

  // ------------------------------------------------------------------ Bauhilfen
  private kanten(mesh: THREE.Mesh, mat: THREE.LineBasicMaterial = this.matKanteFein, winkel = 30): THREE.Mesh {
    mesh.add(new THREE.LineSegments(new THREE.EdgesGeometry(mesh.geometry, winkel), mat));
    return mesh;
  }
  private quader(mat: THREE.Material, x: number, y: number, z: number, b: number, h: number, t: number, kante = true): THREE.Mesh {
    const m = new THREE.Mesh(new THREE.BoxGeometry(b, h, t), mat);
    m.position.set(x, y + h / 2, z);
    return kante ? this.kanten(m) : m;
  }
  private zylinder(mat: THREE.Material, x: number, y: number, z: number, r: number, h: number, seg = 28, kante = true): THREE.Mesh {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, h, seg), mat);
    m.position.set(x, y + h / 2, z);
    return kante ? this.kanten(m, this.matKanteFein, 40) : m;
  }
  private linie(mat: THREE.LineBasicMaterial, punkte: [number, number, number][]): THREE.Line {
    return new THREE.Line(new THREE.BufferGeometry().setFromPoints(punkte.map((p) => new THREE.Vector3(...p))), mat);
  }
  private fliesen(g: THREE.Group, x0: number, z0: number, x1: number, z1: number): void {
    if (!this.texFliesen) return;
    const b = x1 - x0;
    const t = z1 - z0;
    const tex = this.texFliesen.clone();
    tex.needsUpdate = true;
    tex.repeat.set(b / 0.36, t / 0.36);
    const m = new THREE.Mesh(new THREE.PlaneGeometry(b, t), new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false }));
    m.rotation.x = -Math.PI / 2;
    m.position.set((x0 + x1) / 2, BODEN_D + 0.006, (z0 + z1) / 2);
    g.add(m);
  }
  private gelaender(g: THREE.Group, x0: number, z0: number, x1: number, z1: number): void {
    const dx = x1 - x0;
    const dz = z1 - z0;
    const l = Math.hypot(dx, dz);
    const n = Math.max(2, Math.round(l / 0.4));
    const h = 0.5;
    const pts: THREE.Vector3[] = [];
    for (let i = 0; i <= n; i++) {
      const t = i / n;
      pts.push(new THREE.Vector3(x0 + dx * t, BODEN_D, z0 + dz * t), new THREE.Vector3(x0 + dx * t, BODEN_D + h, z0 + dz * t));
    }
    pts.push(new THREE.Vector3(x0, BODEN_D + h, z0), new THREE.Vector3(x1, BODEN_D + h, z1));
    g.add(new THREE.LineSegments(new THREE.BufferGeometry().setFromPoints(pts), this.matGelaender));
  }
  private chip(klasse: string, zahl: string, name: string): { obj: CSS2DObject; chip: Chip } {
    const el = document.createElement("div");
    el.className = `haus-chip ${klasse}`;
    const z = document.createElement("span");
    z.className = "t";
    z.textContent = zahl;
    const n = document.createElement("span");
    n.className = "n";
    n.textContent = name;
    el.append(z, n);
    return { obj: new CSS2DObject(el), chip: { el, zahl: z } };
  }
  private ton(item: HouseItem, sonst: Ton): THREE.MeshLambertMaterial {
    return this.toene[item.tone ?? sonst];
  }

  // ------------------------------------------------------------------ Decks
  private baueDeck(deck: HouseDeck): void {
    const g = new THREE.Group();
    this.deckGruppen.set(deck.key, g);
    this.scene.add(g);

    const platte = deck.plate ?? deck.shell;
    const form = (d: number, mitLoechern: boolean) => {
      const s = new THREE.Shape();
      versetzt(platte, d).forEach(([x, z], i) => (i ? s.lineTo(x, z) : s.moveTo(x, z)));
      s.closePath();
      if (mitLoechern) {
        for (const loch of deck.holes ?? []) {
          const [x0, z0, x1, z1] = loch;
          const h = new THREE.Path();
          h.moveTo(x0, z0);
          h.lineTo(x1, z0);
          h.lineTo(x1, z1);
          h.lineTo(x0, z1);
          h.closePath();
          s.holes.push(h);
        }
      }
      return s;
    };
    const grund = new THREE.Mesh(new THREE.ExtrudeGeometry(form(1.3, true), { depth: 0.3, bevelEnabled: false }), this.matPlatte);
    grund.rotation.x = Math.PI / 2;
    g.add(grund);
    if (this.texRaster) {
      const raster = new THREE.Mesh(new THREE.ShapeGeometry(form(1.3, true)), new THREE.MeshBasicMaterial({ map: this.texRaster, transparent: true, opacity: 0.16, depthWrite: false, side: THREE.DoubleSide }));
      raster.rotation.x = Math.PI / 2;
      raster.position.y = 0.003;
      g.add(raster);
    }
    const rand = new THREE.Mesh(new THREE.ExtrudeGeometry(form(1.42, false), { depth: 0.06, bevelEnabled: false }), this.matPlatteRand);
    rand.rotation.x = Math.PI / 2;
    rand.position.y = -0.3;
    g.add(rand);
    const saum = versetzt(platte, 1.3).map(([x, z]) => [x, 0.012, z] as [number, number, number]);
    saum.push(saum[0]!);
    g.add(this.linie(this.matKanteAmber, saum));

    for (const raum of deck.rooms) this.baueRaum(raum, deck, g);
    for (const w of wandstuecke(deck)) {
      const h = w.aussen ? AUSSEN_H : WAND_H;
      const d = w.aussen ? 0.14 : 0.08;
      const l = w.b - w.a;
      const mitte = (w.a + w.b) / 2;
      const m = w.senkrecht
        ? new THREE.Mesh(new THREE.BoxGeometry(d, h, l), w.aussen ? this.matWandAussen : this.matWand)
        : new THREE.Mesh(new THREE.BoxGeometry(l, h, d), w.aussen ? this.matWandAussen : this.matWand);
      if (w.senkrecht) m.position.set(w.konst, BODEN_D + h / 2, mitte);
      else m.position.set(mitte, BODEN_D + h / 2, w.konst);
      this.kanten(m, w.aussen ? this.matKante : this.matKanteFein);
      g.add(m);
    }
    for (const item of deck.items ?? []) this.baueItem(item, g);
    for (const o of deck.openings ?? []) this.baueOeffnung(o, g);
    for (const k of deck.contacts ?? []) this.baueKontakt(k, g);
    if ((deck.contacts ?? []).length > 0) this.baueSchild(versetzt(deck.alarm_shell ?? deck.shell, 0.32), g);

    const u = umgrenzung(platte);
    const grenzen = { x0: u.x0 - 1.5, x1: u.x1 + 1.5, z0: u.z0 - 1.5, z1: u.z1 + 1.5, h: 2.6 };
    this.deckGrenzen.set(deck.key, grenzen);
    for (const ort of deck.places ?? []) {
      const el = document.createElement("div");
      el.className = "haus-ort";
      el.textContent = ort.text;
      const l = new CSS2DObject(el);
      l.position.set(ort.x, 0.02, ort.z);
      g.add(l);
    }
    const el = document.createElement("div");
    el.className = "haus-deckname";
    el.textContent = deck.name;
    const l = new CSS2DObject(el);
    l.position.set(grenzen.x0, 0.05, grenzen.z0);
    g.add(l);
    this.deckNamen.push({ label: l, ecken: [[grenzen.x0, grenzen.z0], [grenzen.x1, grenzen.z0], [grenzen.x1, grenzen.z1], [grenzen.x0, grenzen.z1]] });
  }

  private baueRaum(raum: HouseRoom, deck: HouseDeck, gruppe: THREE.Group): void {
    const b = raum.x1 - raum.x0;
    const t = raum.z1 - raum.z0;
    const g = new THREE.Group();
    g.position.set((raum.x0 + raum.x1) / 2, 0, (raum.z0 + raum.z1) / 2);
    gruppe.add(g);
    const haupt = (raum.part_of ? deck.rooms.find((r) => r.name === raum.part_of && !r.part_of) : undefined) ?? raum;
    const bodenMat = new THREE.MeshLambertMaterial({ color: 0x2c5d72, emissive: 0x2c5d72, emissiveIntensity: 0.08 });
    let boden: THREE.Mesh | null = null;
    if (!raum.open) {
      boden = new THREE.Mesh(new THREE.BoxGeometry(b - 0.02, BODEN_D, t - 0.02), bodenMat);
      boden.position.y = BODEN_D / 2;
      g.add(boden);
      if (raum.tiles) this.fliesen(gruppe, raum.x0 + 0.06, raum.z0 + 0.06, raum.x1 - 0.06, raum.z1 - 0.06);
    }
    for (const seite of raum.railing ?? "") {
      if (seite === "n") this.gelaender(gruppe, raum.x0, raum.z0, raum.x1, raum.z0);
      if (seite === "s") this.gelaender(gruppe, raum.x0, raum.z1, raum.x1, raum.z1);
      if (seite === "w") this.gelaender(gruppe, raum.x0, raum.z0, raum.x0, raum.z1);
      if (seite === "o") this.gelaender(gruppe, raum.x1, raum.z0, raum.x1, raum.z1);
    }
    let heiz: THREE.Mesh | null = null;
    let heizMat: THREE.MeshBasicMaterial | null = null;
    if (haupt.room_id != null && !raum.open && b > 0.8 && t > 0.8) {
      const tex = HausSzene.schleifenTextur(b - 0.5, t - 0.5);
      heizMat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, opacity: 0, color: 0xffd27a, blending: THREE.AdditiveBlending, depthWrite: false });
      heiz = new THREE.Mesh(new THREE.PlaneGeometry(b - 0.5, t - 0.5), heizMat);
      heiz.rotation.x = -Math.PI / 2;
      heiz.position.y = BODEN_D + 0.012;
      g.add(heiz);
    }
    let label: CSS2DObject | null = null;
    if (!raum.silent && !raum.part_of) {
      const el = document.createElement("div");
      const hatTemp = raum.room_id != null;
      el.className = "haus-chip" + (raum.minor ? " klein" : "") + (raum.cold || raum.tech ? " neben" : "") + (hatTemp ? "" : " name");
      if (hatTemp) {
        const z = document.createElement("span");
        z.className = "t";
        z.textContent = "-";
        el.append(z);
      }
      const n = document.createElement("span");
      n.className = "n";
      n.textContent = raum.name;
      el.append(n);
      label = new CSS2DObject(el);
      label.position.set(0, raum.open ? 0.3 : 1.25, 0);
      g.add(label);
    }
    const knoten: RaumKnoten = { deck, raum, haupt, gruppe: g, boden, bodenMat, heiz, heizMat, label, temp: null, ventil: 0 };
    if (boden) boden.userData.knoten = knoten;
    this.raumKnoten.push(knoten);
    this.raumFarbe(knoten);
  }

  /** Bodenfarbe eines Raums aus seiner Temperatur, gedimmt, wenn ein anderer im Fokus steht. */
  private raumFarbe(r: RaumKnoten): void {
    const haupt = this.raumKnoten.find((k) => k.raum === r.haupt) ?? r;
    const temp = haupt.temp;
    const hatTemp = temp != null;
    const farbe = new THREE.Color(hatTemp ? tempFarbe(temp) : 0x2c5d72);
    const dim = this.fokus != null && this.hauptKnoten(this.fokus) !== haupt;
    r.bodenMat.color.copy(farbe.clone().lerp(new THREE.Color(0x0b2a3a), r.raum.cold ? 0.55 : hatTemp ? 0.1 : 0.45));
    r.bodenMat.emissive.copy(farbe);
    r.bodenMat.emissiveIntensity = dim ? 0.05 : r.raum.cold ? 0.06 : hatTemp ? 0.3 : 0.08;
    if (r.label) {
      r.label.element.classList.toggle("dim", dim);
      r.label.element.classList.toggle("fokus", this.fokus === r);
    }
  }

  private baueOeffnung(o: HouseOpening, g: THREE.Group): void {
    const { senkrecht, konst } = wandlinie(o);
    const { m, h, y0 } = this.scheibe(senkrecht, o.b - o.a, o.door);
    if (senkrecht) m.position.set(konst, BODEN_D + y0 + h / 2, (o.a + o.b) / 2);
    else m.position.set((o.a + o.b) / 2, BODEN_D + y0 + h / 2, konst);
    g.add(m);
  }
  private scheibe(senkrecht: boolean, laenge: number, tuer: boolean): { m: THREE.Mesh; mat: THREE.MeshLambertMaterial; h: number; y0: number } {
    const h = tuer ? WAND_H + 0.1 : 0.7;
    const y0 = tuer ? 0 : 0.4;
    const mat = new THREE.MeshLambertMaterial({ color: tuer ? 0xd9e7ec : 0xbfeeff, transparent: true, opacity: tuer ? 0.55 : 0.5, depthWrite: false, emissive: 0x000000, emissiveIntensity: 1, side: THREE.DoubleSide });
    const m = new THREE.Mesh(new THREE.BoxGeometry(senkrecht ? 0.05 : laenge, h, senkrecht ? laenge : 0.05), mat);
    this.kanten(m, this.matKante);
    return { m, mat, h, y0 };
  }
  private baueKontakt(k: HouseContactPlan, g: THREE.Group): void {
    const laenge = k.b - k.a;
    const senkrecht = k.side === "o" || k.side === "w";
    const angel = new THREE.Group();
    const nachAussen = { n: -1, s: 1, o: 1, w: -1 }[k.side];
    if (senkrecht) angel.position.set(k.at, BODEN_D, k.a);
    else angel.position.set(k.a, BODEN_D, k.at);
    const { m: fluegel, mat, h, y0 } = this.scheibe(senkrecht, laenge, k.door);
    fluegel.position.set(senkrecht ? 0 : laenge / 2, y0 + h / 2, senkrecht ? laenge / 2 : 0);
    angel.add(fluegel);
    g.add(angel);
    const streifenMat = new THREE.MeshBasicMaterial({ color: AMBER, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false });
    const streifen = new THREE.Mesh(new THREE.PlaneGeometry(senkrecht ? 0.9 : laenge + 0.4, senkrecht ? laenge + 0.4 : 0.9), streifenMat);
    streifen.rotation.x = -Math.PI / 2;
    if (senkrecht) streifen.position.set(k.at + nachAussen * 0.45, BODEN_D + 0.01, (k.a + k.b) / 2);
    else streifen.position.set((k.a + k.b) / 2, BODEN_D + 0.01, k.at + nachAussen * 0.45);
    g.add(streifen);
    const el = document.createElement("div");
    el.className = "haus-kontakt";
    el.innerHTML = `<span class="punkt"></span>${k.name} · <b>offen</b>`;
    const label = new CSS2DObject(el);
    label.position.set(senkrecht ? k.at + nachAussen * 1.0 : (k.a + k.b) / 2, 0.6, senkrecht ? (k.a + k.b) / 2 : k.at + nachAussen * 1.0);
    label.visible = false;
    g.add(label);
    const grund = k.door ? 1.15 : 0.6;
    const vorzeichen = { n: 1, s: -1, o: 1, w: -1 }[k.side];
    this.kontaktKnoten.push({ k, angel, mat, streifen: streifenMat, label, winkel: grund * vorzeichen, offen: false, alarm: false });
  }

  private baueSchild(punkte: [number, number][], g: THREE.Group): void {
    const pos: number[] = [];
    const kante: number[] = [];
    const h = 1.45;
    const n = punkte.length;
    for (let i = 0; i < n; i++) {
      const [ax, az] = punkte[i]!;
      const [bx, bz] = punkte[(i + 1) % n]!;
      pos.push(ax, 0, az, bx, 0, bz, bx, h, bz, ax, 0, az, bx, h, bz, ax, h, az);
      kante.push(ax, h, az, bx, h, bz, ax, 0.02, az, bx, 0.02, bz);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    geo.computeVertexNormals();
    const flaeche = new THREE.MeshBasicMaterial({ color: AMBER, transparent: true, opacity: 0, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false });
    const m = new THREE.Mesh(geo, flaeche);
    m.position.y = BODEN_D;
    g.add(m);
    const kg = new THREE.BufferGeometry();
    kg.setAttribute("position", new THREE.Float32BufferAttribute(kante, 3));
    const kanteMat = new THREE.LineBasicMaterial({ color: AMBER, transparent: true, opacity: 0 });
    const k = new THREE.LineSegments(kg, kanteMat);
    k.position.y = BODEN_D;
    g.add(k);
    this.schilde.push({ flaeche, kante: kanteMat });
  }

  // ------------------------------------------------------------------ Moebel und Geraete
  private baueItem(it: HouseItem, g: THREE.Group): void {
    const x = it.x ?? 0;
    const z = it.z ?? 0;
    const y = it.y ?? 0;
    const Q = (mat: THREE.Material, qx: number, qz: number, b: number, t: number, h: number, qy = 0) => {
      const m = this.quader(mat, qx, BODEN_D + qy, qz, b, h, t);
      g.add(m);
      return m;
    };
    const Z = (mat: THREE.Material, zx: number, zz: number, r: number, h: number, zy = 0) => {
      const m = this.zylinder(mat, zx, BODEN_D + zy, zz, r, h);
      g.add(m);
      return m;
    };
    switch (it.kind) {
      case "box":
        Q(this.ton(it, "dark"), x, z, it.b ?? 0.6, it.t ?? 0.6, it.h ?? 0.5, y);
        return;
      case "cylinder":
        Z(this.ton(it, "light"), x, z, it.r ?? 0.3, it.h ?? 0.45, y);
        return;
      case "chair":
        Z(this.toene.light, x, z, it.r ?? 0.19, it.h ?? 0.44, y);
        return;
      case "plant":
        Z(glas(0x3f8f6c, 0.6), x, z, it.r ?? 0.2, it.h ?? 0.6, y);
        return;
      case "tree": {
        // Ein Baum im Dachspalier, in den Farben des Modells: runde Baumscheibe im Pflaster, duenner
        // Stamm, darueber die flache Krone als Scheibe im Glaston der Raeume mit drei zarten
        // Ringen, wie ein Baum im Architektenplan. Kein Gruen und keine Speichen: beides fiel aus
        // dem Bild (gesehen am 30.10.2026).
        const rDach = it.r ?? 1.3;
        const rScheibe = (it.b ?? 2.0) / 2;
        const hStamm = it.h ?? 2.2;
        const scheibe = new THREE.Mesh(new THREE.CircleGeometry(rScheibe, 48), new THREE.MeshLambertMaterial({ color: 0x0a2331 }));
        scheibe.rotation.x = -Math.PI / 2;
        scheibe.position.set(x, 0.008, z);
        g.add(scheibe);
        const rand = new THREE.Mesh(new THREE.RingGeometry(rScheibe - 0.03, rScheibe, 48), new THREE.MeshBasicMaterial({ color: KANTE, transparent: true, opacity: 0.3, depthWrite: false }));
        rand.rotation.x = -Math.PI / 2;
        rand.position.set(x, 0.01, z);
        g.add(rand);
        g.add(this.zylinder(this.toene.light, x, 0, z, 0.07, hStamm, 12, false));
        const krone = new THREE.Mesh(new THREE.CylinderGeometry(rDach, rDach, 0.08, 48), glas(0x7fd3e6, 0.16, { side: THREE.DoubleSide }));
        krone.position.set(x, hStamm + 0.04, z);
        g.add(krone);
        for (const [anteil, deck] of [[1, 0.55], [0.72, 0.3], [0.42, 0.22]] as [number, number][]) {
          const ring = new THREE.Mesh(new THREE.RingGeometry(rDach * anteil - 0.012, rDach * anteil, 64), new THREE.MeshBasicMaterial({ color: KANTE, transparent: true, opacity: deck, depthWrite: false, side: THREE.DoubleSide }));
          ring.rotation.x = -Math.PI / 2;
          ring.position.set(x, hStamm + 0.085, z);
          g.add(ring);
        }
        const schatten = HausSzene.kontaktSchatten(rDach * 2.4, rDach * 2.4);
        schatten.position.set(x, 0.013, z);
        g.add(schatten);
        return;
      }
      case "bed": {
        const b = it.b ?? 1.6;
        const t = it.t ?? 2.0;
        const kopf = it.head ?? "n";
        Q(this.toene.light, x, z, b, t, 0.42, y);
        const dz = kopf === "n" ? 0.18 : kopf === "s" ? -0.18 : 0;
        const dx = kopf === "w" ? 0.18 : kopf === "o" ? -0.18 : 0;
        Q(this.toene.soft, x + dx, z + dz, kopf === "n" || kopf === "s" ? b - 0.2 : b - 0.5, kopf === "n" || kopf === "s" ? t - 0.5 : t - 0.2, 0.1, y + 0.42);
        if (kopf === "n" || kopf === "s") Q(this.toene.dark, x, kopf === "n" ? z - t / 2 + 0.05 : z + t / 2 - 0.05, b + 0.06, 0.1, 0.8, y);
        else Q(this.toene.dark, kopf === "w" ? x - b / 2 + 0.05 : x + b / 2 - 0.05, z, 0.1, t + 0.06, 0.8, y);
        return;
      }
      case "stove": {
        const r = it.r ?? 0.25;
        Z(it.tone ? this.ton(it, "dark") : this.toene.dark, x, z, r, 0.9, y);
        const mat = this.matGlut.clone();
        const glut = new THREE.Mesh(new THREE.PlaneGeometry(r * 1.3, 0.3), mat);
        glut.position.set(x, BODEN_D + y + 0.4, z + r + 0.01);
        g.add(glut);
        this.gluten.push({ mat, device: it.device ?? null });
        Z(this.toene.dark, x, z, 0.05, 0.5, y + 0.9);
        return;
      }
      case "ladder": {
        const x0 = it.x0 ?? x;
        const z0 = it.z0 ?? z;
        const x1 = it.x1 ?? x0 + 1;
        const z1 = it.z1 ?? z0;
        const breite = it.b ?? 0.4;
        const dx = x1 - x0;
        const dz = z1 - z0;
        for (let i = 0; i < 5; i++) {
          const t = (i + 0.5) / 5;
          g.add(this.quader(this.matStufe, x0 + dx * t, BODEN_D + y + 0.1 + i * 0.11, z0 + dz * t, Math.abs(dx) > Math.abs(dz) ? 0.2 : breite, 0.04, Math.abs(dx) > Math.abs(dz) ? breite : 0.2));
        }
        return;
      }
      case "loft": {
        const x0 = it.x0 ?? x;
        const z0 = it.z0 ?? z;
        const x1 = it.x1 ?? x0 + 1;
        const z1 = it.z1 ?? z0 + 1;
        Q(this.matEmpore, (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, 0.05, it.y ?? 0.66);
        return;
      }
      case "panel":
        Q(this.ton(it, "dark"), x, z, it.b ?? 0.06, it.t ?? 0.06, it.h ?? WAND_H - 0.05, y);
        return;
      case "tiles":
        this.fliesen(g, it.x0 ?? x, it.z0 ?? z, it.x1 ?? x + 1, it.z1 ?? z + 1);
        return;
      case "ground": {
        const m = new THREE.Mesh(new THREE.PlaneGeometry(it.b ?? 1, it.t ?? 1), this.ton(it, "paving"));
        m.rotation.x = -Math.PI / 2;
        m.position.set(x, 0.005, z);
        g.add(m);
        return;
      }
      case "wall":
        g.add(this.kanten(this.quader(this.matWandAussen, x, y, z, it.b ?? 0.2, it.h ?? 0.9, it.t ?? 0.2, false), this.matKante));
        return;
      case "gate": {
        const h = it.h ?? 0.85;
        const senkrecht = it.x0 == null && it.x1 == null;
        const a = senkrecht ? (it.z0 ?? z) : (it.x0 ?? x);
        const b = senkrecht ? (it.z1 ?? z + 1) : (it.x1 ?? x + 1);
        const p = (s: number, hh: number): [number, number, number] => (senkrecht ? [x, hh, s] : [s, hh, z]);
        g.add(this.linie(this.matKante, [p(a, 0.02), p(a, h), p(b, h), p(b, 0.02)]));
        const n = Math.max(2, Math.round((b - a) / 0.3));
        for (let i = 1; i < n; i++) g.add(this.linie(i === Math.round(n / 2) ? this.matKante : this.matKanteFein, [p(a + ((b - a) * i) / n, 0.02), p(a + ((b - a) * i) / n, h)]));
        return;
      }
      case "car":
        g.add(this.auto(x, z, it.angle ?? 0));
        return;
      case "wallbox": {
        Q(this.toene.dark, x, z, it.b ?? 0.24, it.t ?? 0.42, it.h ?? 0.4, y + 0.45);
        const lampe = new THREE.Mesh(new THREE.PlaneGeometry(0.1, 0.1), this.matGlut);
        lampe.position.set(x + (it.b ?? 0.24) / 2 + 0.01, BODEN_D + y + 0.75, z);
        lampe.rotation.y = Math.PI / 2;
        g.add(lampe);
        if (it.x1 != null && it.z1 != null) {
          const kabel = new THREE.Mesh(
            new THREE.TubeGeometry(new THREE.CatmullRomCurve3([new THREE.Vector3(x, 0.6, z), new THREE.Vector3((x + it.x1) / 2, 0.25, (z + it.z1) / 2), new THREE.Vector3(it.x1, 0.5, it.z1)]), 24, 0.035, 8, false),
            new THREE.MeshBasicMaterial({ color: AMBER, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }),
          );
          g.add(kabel);
        }
        const { obj, chip } = this.chip("technik", "-", it.label ?? "Wallbox");
        obj.position.set(x, 0.2, z + 1.1);
        g.add(obj);
        this.chips.wallbox.push(chip);
        return;
      }
      case "heat_pump": {
        const dir = it.dir ?? "n";
        const laengs = dir === "n" || dir === "s";
        const wp = new THREE.Group();
        wp.position.set(x, 0, z);
        g.add(wp);
        wp.add(this.quader(this.toene.light, 0, 0, 0, laengs ? 1.6 : 0.75, 1.35, laengs ? 0.75 : 1.6));
        const rotor = new THREE.Group();
        const v = { n: [0, -0.39], s: [0, 0.39], o: [0.39, 0], w: [-0.39, 0] }[dir];
        rotor.position.set(v[0]!, 0.72, v[1]!);
        if (!laengs) rotor.rotation.y = Math.PI / 2;
        wp.add(rotor);
        for (let i = 0; i < 5; i++) {
          const blatt = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.46, 0.02), new THREE.MeshBasicMaterial({ color: 0xe08b4a, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }));
          blatt.position.y = 0.27;
          const arm = new THREE.Group();
          arm.rotation.z = (i / 5) * Math.PI * 2;
          arm.add(blatt);
          rotor.add(arm);
        }
        const ring = new THREE.Mesh(new THREE.TorusGeometry(0.5, 0.025, 8, 48), new THREE.MeshBasicMaterial({ color: 0xe08b4a, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
        ring.position.copy(rotor.position);
        ring.rotation.copy(rotor.rotation);
        wp.add(ring);
        this.rotoren.push(rotor);
        const { obj, chip } = this.chip("technik", "-", it.label ?? "Wärmepumpe");
        obj.position.set(v[0]! * 3.3, 0.1, v[1]! * 3.3);
        wp.add(obj);
        this.chips.waermepumpe.push(chip);
        return;
      }
      case "buffer": {
        const schichten: THREE.MeshLambertMaterial[] = [];
        let yy = BODEN_D + y;
        for (let i = 0; i < 4; i++) {
          const mat = new THREE.MeshLambertMaterial({ color: 0x2b4a58, emissive: 0x2b4a58, emissiveIntensity: 0.05, transparent: true, opacity: 0.85 });
          const m = new THREE.Mesh(new THREE.CylinderGeometry(it.r ?? 0.5, it.r ?? 0.5, 0.6, 32), mat);
          m.position.set(x, yy + 0.3, z);
          g.add(m);
          schichten.unshift(mat);
          yy += 0.6;
        }
        const deckel = new THREE.Mesh(new THREE.CylinderGeometry((it.r ?? 0.5) + 0.04, (it.r ?? 0.5) + 0.04, 0.08, 32), new THREE.MeshBasicMaterial({ color: KANTE, transparent: true, opacity: 0.6 }));
        deckel.position.set(x, yy + 0.04, z);
        g.add(deckel);
        this.pufferSchichten.push(schichten);
        const { obj, chip } = this.chip("technik", "-", it.label ?? "Puffer");
        obj.position.set(x, 2.75, z);
        g.add(obj);
        this.chips.puffer.push(chip);
        return;
      }
      case "indoor_unit": {
        const dir = it.dir ?? "w";
        const laengs = dir === "n" || dir === "s";
        const einheit = new THREE.Group();
        einheit.position.set(x, 0, z);
        g.add(einheit);
        einheit.add(this.quader(this.toene.light, 0, BODEN_D + 0.3, 0, laengs ? 0.9 : 0.42, 0.85, laengs ? 0.42 : 0.9));
        const led = new THREE.Mesh(new THREE.PlaneGeometry(0.05, 0.05), this.matGlut);
        const v = { n: [0, -0.215], s: [0, 0.215], o: [0.215, 0], w: [-0.215, 0] }[dir];
        led.position.set(v[0]!, BODEN_D + 1.05, v[1]!);
        led.rotation.y = { n: Math.PI, s: 0, o: Math.PI / 2, w: -Math.PI / 2 }[dir];
        einheit.add(led);
        const el = document.createElement("div");
        el.className = "haus-chip klein name";
        const n = document.createElement("span");
        n.className = "n";
        n.textContent = it.label ?? "Inneneinheit";
        el.append(n);
        const l = new CSS2DObject(el);
        l.position.set(0, 1.5, 0);
        einheit.add(l);
        this.nurNah.push(l);
        return;
      }
      case "pipe": {
        const pts = (it.points ?? []).map((p) => new THREE.Vector3(p[0], p[1], p[2]));
        if (pts.length < 2) return;
        g.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), Math.max(8, pts.length * 8), 0.05, 8, false), this.matRohr));
        return;
      }
      case "flight": {
        const x0 = it.x0 ?? x;
        const z0 = it.z0 ?? z;
        const x1 = it.x1 ?? x0 + 2;
        const z1 = it.z1 ?? z0;
        const breite = it.b ?? 1.0;
        const stufen = it.steps ?? 8;
        const y0 = it.y ?? 0;
        const y1 = it.y1 ?? y0 + 1.0;
        const dx = x1 - x0;
        const dz = z1 - z0;
        const laengs = Math.abs(dx) >= Math.abs(dz);
        const laenge = Math.hypot(dx, dz);
        const tritt = laenge / stufen;
        // Jede Stufe ist ein Block vom Fuss des Laufs bis zu ihrer Trittflaeche: so sieht man die
        // Wangen, nicht nur schwebende Bretter.
        const unten = Math.min(y0, y1);
        for (let i = 0; i < stufen; i++) {
          const t = (i + 0.5) / stufen;
          const tritt_y = y0 + ((y1 - y0) * (i + 1)) / stufen;
          const hoehe = Math.max(0.03, tritt_y - unten);
          g.add(this.quader(this.matStufe, x0 + dx * t, BODEN_D + unten, z0 + dz * t, laengs ? tritt * 0.96 : breite, hoehe, laengs ? breite : tritt * 0.96));
        }
        return;
      }
      case "landing":
        Q(this.matStufe, x, z, it.b ?? 1.5, it.t ?? 1.0, it.h ?? 0.1, y);
        return;
      case "pit": {
        const m = new THREE.Mesh(new THREE.PlaneGeometry(it.b ?? 2, it.t ?? 2), this.matGrube);
        m.rotation.x = -Math.PI / 2;
        m.position.set(x, y, z);
        g.add(m);
        return;
      }
      default:
        return;
    }
  }

  private auto(x: number, z: number, winkel: number): THREE.Group {
    const grp = new THREE.Group();
    grp.position.set(x, BODEN_D, z);
    grp.rotation.y = winkel;
    // Koerper
    const xs: number[] = [];
    for (let sx = 2.42; sx > -2.42; sx -= 0.07) xs.push(sx);
    xs.push(-2.42);
    const ringe = xs.map((sx) => autoRing(autoBreite(sx), autoGuertel(sx), autoHoehe(sx)));
    const M = ringe[0]!.ring.length;
    const pos: number[] = [];
    xs.forEach((sx, i) => ringe[i]!.ring.forEach(([rz, ry]) => pos.push(sx, ry, rz)));
    const koerper: number[] = [];
    const glasIdx: number[] = [];
    for (let i = 0; i < xs.length - 1; i++) {
      const xm = (xs[i]! + xs[i + 1]!) / 2;
      const info = ringe[i]!;
      for (let j = 0; j < M; j++) {
        const j2 = (j + 1) % M;
        const a = i * M + j;
        const b = i * M + j2;
        const c = (i + 1) * M + j2;
        const d = (i + 1) * M + j;
        const u1 = autoAnteil(info, j);
        const u2 = autoAnteil(info, j2);
        let istGlas = false;
        if (u1 != null && u2 != null) {
          const u = (u1 + u2) / 2;
          istGlas = xm <= autoVorn(u) && xm >= autoHinten(u);
        }
        (istGlas ? glasIdx : koerper).push(a, b, c, a, c, d);
      }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    geo.setIndex(koerper.concat(glasIdx));
    geo.addGroup(0, koerper.length, 0);
    geo.addGroup(koerper.length, glasIdx.length, 1);
    geo.computeVertexNormals();
    grp.add(new THREE.Mesh(geo, [this.matLack, this.matScheibe]));
    // Scheibenraender
    const probe = autoRing(autoBreite(0), autoGuertel(0), autoHoehe(0));
    for (const grenze of [autoVorn, autoHinten]) {
      const pts: THREE.Vector3[] = [];
      for (let j = probe.schulter; j < probe.n; j++) {
        const u = autoAnteil(probe, j) ?? 0;
        const gx = grenze(u);
        const ring = autoRing(autoBreite(gx), autoGuertel(gx), autoHoehe(gx)).ring[j]!;
        pts.push(new THREE.Vector3(gx, ring[1] + 0.006, ring[0] * 1.006));
      }
      const links = pts.slice(0, -1).reverse().map((p) => new THREE.Vector3(p.x, p.y, -p.z));
      grp.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts.concat(links)), this.matGuertel));
    }
    // Lichtbaender
    const band = (x0: number, x1: number, mat: THREE.Material) => {
      const ra = autoRing(autoBreite(x0), autoGuertel(x0), autoHoehe(x0));
      const rb = autoRing(autoBreite(x1), autoGuertel(x1), autoHoehe(x1));
      const idx: number[] = [];
      for (let j = ra.schulter; j < ra.schulter + 5; j++) idx.push(j);
      const spiegel = (j: number) => ra.ring.length - j;
      const strecke = [...idx.map((j) => spiegel(j)).reverse(), ...idx];
      const bpos: number[] = [];
      const bind: number[] = [];
      strecke.forEach((j) => {
        const [rz, ry] = ra.ring[j]!;
        bpos.push(x0, ry + 0.012, rz * 1.015);
      });
      strecke.forEach((j) => {
        const [rz, ry] = rb.ring[j]!;
        bpos.push(x1, ry + 0.012, rz * 1.015);
      });
      const L = strecke.length;
      for (let k = 0; k < L - 1; k++) bind.push(k, k + 1, L + k + 1, k, L + k + 1, L + k);
      const bg = new THREE.BufferGeometry();
      bg.setAttribute("position", new THREE.Float32BufferAttribute(bpos, 3));
      bg.setIndex(bind);
      bg.computeVertexNormals();
      return new THREE.Mesh(bg, mat);
    };
    grp.add(band(2.33, 2.26, this.matLeuchte));
    grp.add(band(-2.3, -2.37, this.matRuecklicht));
    for (const seite of [-1, 1]) {
      const pts: THREE.Vector3[] = [];
      for (let sx = 2.3; sx >= -2.3; sx -= 0.1) pts.push(new THREE.Vector3(sx, autoGuertel(sx) + 0.004, seite * autoBreite(sx) * 1.004));
      grp.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), this.matGuertel));
    }
    for (const [dx, dz] of [[-1.5, -1], [1.5, -1], [-1.5, 1], [1.5, 1]] as [number, number][]) {
      const w = autoBreite(dx);
      const rad = new THREE.Mesh(new THREE.CylinderGeometry(0.37, 0.37, 0.26, 32), this.matReifen);
      rad.rotation.x = Math.PI / 2;
      rad.position.set(dx, 0.37, dz * (w - 0.14));
      grp.add(rad);
      const felge = new THREE.Mesh(new THREE.RingGeometry(0.16, 0.27, 32), this.matFelge);
      felge.rotation.y = dz > 0 ? 0 : Math.PI;
      felge.position.set(dx, 0.37, dz * (w - 0.004));
      grp.add(felge);
    }
    const schatten = HausSzene.kontaktSchatten(5.6, 2.9);
    schatten.position.y = -BODEN_D + 0.012;
    grp.add(schatten);
    return grp;
  }

  // ------------------------------------------------------------------ Kamera
  private projektionSetzen(): void {
    const c = Math.cos(this.theta);
    const s = Math.sin(this.theta);
    const r = strahl(this.theta);
    const { sxC, suC, W, H } = this.ansicht;
    const m = new THREE.Matrix4();
    m.set(
      (2 / W) * c, (2 / W) * K_X, -(2 / W) * s, -(2 / W) * sxC,
      -(2 / H) * s, (2 / H) * K_Y, -(2 / H) * c, -(2 / H) * suC,
      -r[0] / this.tiefeHalb, -r[1] / this.tiefeHalb, -r[2] / this.tiefeHalb, -this.tiefeMitte / this.tiefeHalb,
      0, 0, 0, 1,
    );
    this.camera.projectionMatrix.copy(m);
    this.camera.projectionMatrixInverse.copy(m).invert();
  }

  private ecken(b: { x0: number; x1: number; z0: number; z1: number; h: number }, pos: THREE.Vector3): THREE.Vector3[] {
    const pts: THREE.Vector3[] = [];
    for (const y of [-0.4, b.h]) for (const x of [b.x0, b.x1]) for (const z of [b.z0, b.z1]) pts.push(new THREE.Vector3(x, y, z).add(pos));
    return pts;
  }
  private ausdehnung(key: string, th: number): { breite: number; hoehe: number } {
    const b = this.deckGrenzen.get(key)!;
    const e = this.ecken(b, new THREE.Vector3()).map((p) => bildschirm(p.x, p.y, p.z, th));
    const sx = e.map((q) => q.sx);
    const su = e.map((q) => q.su);
    return { breite: Math.max(...sx) - Math.min(...sx), hoehe: Math.max(...su) - Math.min(...su) };
  }
  /** Die Decks nebeneinander (quer) oder untereinander (hochkant), im Bildschirm gemessen. */
  private anordnen(th: number): void {
    let laufSx = 0;
    let laufSu = 0;
    const c = Math.cos(th);
    const s = Math.sin(th);
    this.plan.decks.forEach((deck, i) => {
      const g = this.deckGruppen.get(deck.key)!;
      const sichtbar = this.sichtbar === "alle" || this.sichtbar === deck.key;
      g.visible = sichtbar;
      if (i === 0 || this.sichtbar !== "alle") {
        g.position.set(0, 0, 0);
      } else {
        const dxp = this.telefon ? 0 : laufSx;
        const dzp = this.telefon ? -laufSu : 0;
        g.position.set(dxp * c + dzp * s, 0, -dxp * s + dzp * c);
      }
      const a = this.ausdehnung(deck.key, th);
      laufSx += a.breite + 3.6;
      laufSu += a.hoehe + 2.0;
    });
  }
  private freierBereich(): { x: number; y: number; w: number; h: number } {
    const w = this.root.clientWidth;
    const h = this.root.clientHeight;
    const panel = this.fokus ? (this.telefon ? 0 : 340) : 0;
    const unten = this.fokus && this.telefon ? 230 : 0;
    return { x: 16, y: 18, w: Math.max(80, w - 32 - panel), h: Math.max(80, h - 36 - unten) };
  }
  private ausschnittBerechnen(): void {
    const w = this.root.clientWidth || 1;
    const h = this.root.clientHeight || 1;
    const frei = this.freierBereich();
    this.anordnen(this.thetaZiel);
    let pts: THREE.Vector3[] = [];
    if (this.fokus) {
      const r = this.fokus.raum;
      const g = this.deckGruppen.get(this.fokus.deck.key)!;
      for (const y of [-0.2, 2.2]) for (const x of [r.x0 - 0.8, r.x1 + 0.8]) for (const z of [r.z0 - 0.8, r.z1 + 0.8]) pts.push(new THREE.Vector3(x, y, z).add(g.position));
    } else {
      for (const deck of this.plan.decks) {
        const g = this.deckGruppen.get(deck.key)!;
        if (g.visible) pts = pts.concat(this.ecken(this.deckGrenzen.get(deck.key)!, g.position));
      }
    }
    const sx = pts.map((p) => bildschirm(p.x, p.y, p.z, this.thetaZiel).sx);
    const su = pts.map((p) => bildschirm(p.x, p.y, p.z, this.thetaZiel).su);
    const minSx = Math.min(...sx);
    const maxSx = Math.max(...sx);
    const minSu = Math.min(...su);
    const maxSu = Math.max(...su);
    const rand = 0.8;
    const scale = Math.min(frei.w / (maxSx - minSx + 2 * rand), frei.h / (maxSu - minSu + 2 * rand));
    this.ansichtZiel.W = w / scale;
    this.ansichtZiel.H = h / scale;
    const ndcX = (2 * (frei.x + frei.w / 2)) / w - 1;
    const ndcY = 1 - (2 * (frei.y + frei.h / 2)) / h;
    this.ansichtZiel.sxC = (minSx + maxSx) / 2 - (ndcX * this.ansichtZiel.W) / 2;
    this.ansichtZiel.suC = (minSu + maxSu) / 2 - (ndcY * this.ansichtZiel.H) / 2;
    const r = strahl(this.thetaZiel);
    let alle: THREE.Vector3[] = [];
    for (const deck of this.plan.decks) alle = alle.concat(this.ecken(this.deckGrenzen.get(deck.key)!, this.deckGruppen.get(deck.key)!.position));
    const t = alle.map((p) => -(p.x * r[0] + p.y * r[1] + p.z * r[2]));
    this.tiefeMitte = (Math.min(...t) + Math.max(...t)) / 2;
    this.tiefeHalb = (Math.max(...t) - Math.min(...t)) / 2 + 8;
    this.anordnen(this.theta);
  }
  private groesse(): void {
    const w = this.root.clientWidth || 1;
    const h = this.root.clientHeight || 1;
    this.telefon = w < TELEFON_BREITE;
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
    this.labels.setSize(w, h);
    this.bloom.resolution.set(w, h);
    this.ausschnittBerechnen();
  }
  private lichtSetzen(): void {
    const erstes = this.plan.decks[0]!;
    const g0 = this.deckGrenzen.get(erstes.key)!;
    const mitte = new THREE.Vector3((g0.x0 + g0.x1) / 2, 0, (g0.z0 + g0.z1) / 2);
    const c = Math.cos(this.theta);
    const s = Math.sin(this.theta);
    const links = new THREE.Vector3(-c, 0, s).multiplyScalar(14);
    const r = strahl(this.theta);
    const vorn = new THREE.Vector3(r[0], 0, r[2]).normalize().multiplyScalar(8);
    this.key.position.copy(mitte).add(links).add(vorn).add(new THREE.Vector3(0, 22, 0));
    this.key.target.position.copy(mitte);
    this.rim.position.copy(mitte).sub(links).sub(vorn).add(new THREE.Vector3(0, 10, 0));
    this.rim.target.position.copy(mitte);
  }

  // ------------------------------------------------------------------ Antippen
  private readonly aufPointerDown = (e: PointerEvent) => {
    this.zeiger = { x: e.clientX, y: e.clientY, t: performance.now() };
  };
  private readonly aufPointerUp = (e: PointerEvent) => {
    const z = this.zeiger;
    this.zeiger = null;
    if (!z || Math.hypot(e.clientX - z.x, e.clientY - z.y) > 8 || performance.now() - z.t > 600) return;
    const rect = this.root.getBoundingClientRect();
    const px = e.clientX - rect.left;
    const py = e.clientY - rect.top;
    const w = this.root.clientWidth || 1;
    const h = this.root.clientHeight || 1;
    const nx = (px / w) * 2 - 1;
    const ny = -(py / h) * 2 + 1;
    const nah = new THREE.Vector3(nx, ny, -1).applyMatrix4(this.camera.projectionMatrixInverse);
    const fern = new THREE.Vector3(nx, ny, 1).applyMatrix4(this.camera.projectionMatrixInverse);
    const rc = new THREE.Raycaster();
    rc.set(nah, fern.sub(nah).normalize());
    const boeden = this.raumKnoten.filter((r) => r.boden && this.deckGruppen.get(r.deck.key)?.visible).map((r) => r.boden!);
    const treffer = rc.intersectObjects(boeden, false);
    if (treffer.length) {
      const knoten = this.hauptKnoten(treffer[0]!.object.userData.knoten as RaumKnoten);
      this.setzeFokusKnoten(knoten === this.fokus ? null : knoten, true);
    } else if (this.fokus) this.setzeFokusKnoten(null, true);
  };
  private hauptKnoten(k: RaumKnoten): RaumKnoten {
    return this.raumKnoten.find((r) => r.deck === k.deck && r.raum === k.haupt) ?? k;
  }
  private setzeFokusKnoten(k: RaumKnoten | null, melden: boolean): void {
    this.fokus = k ? this.hauptKnoten(k) : null;
    for (const r of this.raumKnoten) this.raumFarbe(r);
    this.ausschnittBerechnen();
    if (melden) this.onFokus(this.fokus ? { deck: this.fokus.deck.key, raum: this.fokus.raum } : null);
  }

  // ------------------------------------------------------------------ Alarm
  private alarmAnwenden(): void {
    const farbe = { unscharf: 0x6f8a95, zuhause: AMBER, unterwegs: ORANGE, schaltet: AMBER, ausgeloest: ROT, unbekannt: 0x6f8a95 }[this.alarm];
    for (const s of this.schilde) {
      s.flaeche.color.set(farbe);
      s.kante.color.set(farbe);
    }
    for (const kk of this.kontaktKnoten) {
      kk.alarm = this.alarm === "ausgeloest" && kk.offen;
      kk.label.element.classList.toggle("alarm", kk.alarm);
    }
  }

  // ------------------------------------------------------------------ Takt
  private takt = (): void => {
    if (this.verworfen) return;
    this.raf = requestAnimationFrame(this.takt);
    const t = this.uhr.getElapsedTime();
    if (this.theta !== this.thetaZiel) {
      this.theta += (this.thetaZiel - this.theta) * 0.08;
      if (Math.abs(this.thetaZiel - this.theta) < 0.0005) this.theta = this.thetaZiel;
      this.anordnen(this.theta);
    }
    for (const k of ["sxC", "suC", "W", "H"] as const) this.ansicht[k] += (this.ansichtZiel[k] - this.ansicht[k]) * 0.1;
    this.projektionSetzen();
    this.lichtSetzen();
    const c = Math.cos(this.theta);
    const sn = Math.sin(this.theta);
    for (const d of this.deckNamen) {
      const beste = d.ecken.map(([x, z]) => ({ x, z, w: bildschirm(x, 0, z, this.theta).sx - bildschirm(x, 0, z, this.theta).su })).sort((a, b) => a.w - b.w)[0]!;
      d.label.position.set(beste.x + 0.3 * c + -1.1 * sn, 0.05, beste.z - 0.3 * sn + -1.1 * c);
    }
    const pxProMeter = (this.root.clientWidth || 1) / this.ansicht.W;
    for (const r of this.raumKnoten) if (r.label && r.raum.minor) r.label.visible = pxProMeter > 30 || this.fokus === r;
    for (const l of this.nurNah) l.visible = pxProMeter > 30;
    this.labels.domElement.classList.toggle("nurzahl", pxProMeter < 27 && !this.fokus);
    // **Zwei offene Tueren, zwei Fahnen, ein Wortsalat.** Nebeneinander gelesen ergab das am
    // 30.10.2026 „Gartentuer 1 offen offen": zwei Beschriftungen, die sich bei kleinem Massstab
    // ueberlagerten. Unter 26 Punkten je Meter bleibt deshalb nur der Punkt stehen; wo etwas offen
    // ist, sagen weiter der leuchtende Fluegel und der Streifen am Boden, und welche Tuer es ist,
    // steht in der Konsole.
    this.labels.domElement.classList.toggle("nurpunkt", pxProMeter < 26);

    for (const r of this.raumKnoten) {
      if (!r.heizMat) continue;
      const dim = this.fokus && this.hauptKnoten(this.fokus) !== this.hauptKnoten(r) ? 0.25 : 1;
      const v = this.hauptKnoten(r).ventil;
      r.heizMat.opacity = v > 0 ? dim * (0.22 + 0.5 * v) * (0.8 + 0.2 * Math.sin(t * 1.4 + r.raum.x0)) : 0;
    }
    const wpLaeuft = (this.live?.waermepumpeKw ?? 0) > 0.2;
    for (const rotor of this.rotoren) rotor.rotation.z = wpLaeuft ? t * 2.2 : rotor.rotation.z;
    for (const gl of this.gluten) {
      const an = gl.device === "pellet" ? this.live?.ofenLaeuft === true : false;
      gl.mat.opacity = an ? 0.7 + 0.2 * Math.sin(t * 3.1) + 0.1 * Math.sin(t * 7.3) : 0.08;
    }
    this.matGlut.opacity = 0.7 + 0.2 * Math.sin(t * 3.1);
    for (const kk of this.kontaktKnoten) {
      const ziel = kk.offen ? kk.winkel * (0.94 + 0.06 * Math.sin(t * 0.8)) : 0;
      kk.angel.rotation.y += (ziel - kk.angel.rotation.y) * 0.08;
      const farbe = kk.alarm ? ROT : AMBER;
      kk.mat.emissive.set(kk.offen ? farbe : 0x000000);
      kk.mat.emissiveIntensity = kk.offen ? (kk.alarm ? 1.6 + 0.8 * Math.sin(t * 9) : 0.9) : 0;
      kk.mat.opacity = kk.offen ? 0.9 : kk.k.door ? 0.55 : 0.5;
      kk.streifen.color.set(farbe);
      kk.streifen.opacity = kk.offen ? (kk.alarm ? 0.5 + 0.3 * Math.sin(t * 9) : 0.28 + 0.1 * Math.sin(t * 2)) : 0;
    }
    const a = { unscharf: [0, 0, 0], zuhause: [0.07, 0.7, 0.5], unterwegs: [0.1, 0.85, 1.0], schaltet: [0.05, 0.6, 2.0], ausgeloest: [0.16, 1.0, 6], unbekannt: [0, 0, 0] }[this.alarm];
    const puls = a[2] ? 0.75 + 0.25 * Math.sin(t * a[2]! * 2) : 1;
    for (const s of this.schilde) {
      s.flaeche.opacity = a[0]! * puls;
      s.kante.opacity = a[1]! * (this.alarm === "ausgeloest" ? (Math.sin(t * 9) > 0 ? 1 : 0.3) : puls);
    }
    if (document.visibilityState !== "hidden") {
      this.composer.render();
      this.labels.render(this.scene, this.camera);
    }
  };
}
