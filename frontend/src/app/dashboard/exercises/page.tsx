"use client"

import { useEffect, useState, useCallback } from "react"
import {
    Exercise, ExerciseGroup,
    getExercises, createExercise, updateExercise,
    getFavoriteExerciseIds, toggleFavoriteExercise,
    getExerciseGroups, createExerciseGroup, deleteExerciseGroup,
    addExerciseGroupItem, removeExerciseGroupItem, updateExerciseGroupItem,
} from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent } from "@/components/ui/card"
import {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog"
import {
    Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select"
import {
    Plus, Star, Search, Pencil, Trash2, Video, Layers, X, ChevronDown, ChevronUp,
} from "lucide-react"

const MUSCLE_GROUPS = ["CHEST", "BACK", "LEGS", "ARMS", "SHOULDERS", "CORE", "CARDIO"]
const CATEGORIES = ["Musculação", "Cardio", "Funcional", "Mobilidade", "Alongamento", "HIIT"]

function youtubeIdFromUrl(url: string | null | undefined): string | null {
    if (!url) return null
    const match = url.match(/(?:youtu\.be\/|v=|\/embed\/)([A-Za-z0-9_-]{11})/)
    return match ? match[1] : null
}

// ─────────────────────────────────────────────────────────────
// Exercise Form Dialog
// ─────────────────────────────────────────────────────────────
function ExerciseDialog({
    open, onClose, initial, onSave,
}: {
    open: boolean
    onClose: () => void
    initial?: Exercise | null
    onSave: (ex: Exercise) => void
}) {
    const [name, setName] = useState(initial?.name ?? "")
    const [category, setCategory] = useState(initial?.category ?? "")
    const [muscleGroup, setMuscleGroup] = useState(initial?.muscle_group ?? "")
    const [videoUrl, setVideoUrl] = useState(initial?.video_url ?? "")
    const [description, setDescription] = useState(initial?.description ?? "")
    const [saving, setSaving] = useState(false)

    useEffect(() => {
        setName(initial?.name ?? "")
        setCategory(initial?.category ?? "")
        setMuscleGroup(initial?.muscle_group ?? "")
        setVideoUrl(initial?.video_url ?? "")
        setDescription(initial?.description ?? "")
    }, [initial, open])

    const videoId = youtubeIdFromUrl(videoUrl)

    const handleSave = async () => {
        if (!name || !category) return
        setSaving(true)
        try {
            const payload = { name, category, muscle_group: muscleGroup || undefined, video_url: videoUrl || undefined, description: description || undefined }
            const result = initial
                ? await updateExercise(initial.id, payload)
                : await createExercise({ ...payload, is_iot_compatible: false })
            onSave(result)
            onClose()
        } finally {
            setSaving(false)
        }
    }

    return (
        <Dialog open={open} onOpenChange={v => !v && onClose()}>
            <DialogContent className="max-w-lg">
                <DialogHeader>
                    <DialogTitle>{initial ? "Editar exercício" : "Novo exercício"}</DialogTitle>
                </DialogHeader>

                <div className="space-y-4">
                    <div>
                        <label className="text-xs text-muted-foreground mb-1 block">Nome *</label>
                        <Input value={name} onChange={e => setName(e.target.value)} placeholder="Ex: Supino Reto" />
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                        <div>
                            <label className="text-xs text-muted-foreground mb-1 block">Categoria *</label>
                            <Select value={category} onValueChange={setCategory}>
                                <SelectTrigger><SelectValue placeholder="Selecionar" /></SelectTrigger>
                                <SelectContent>
                                    {CATEGORIES.map(c => <SelectItem key={c} value={c}>{c}</SelectItem>)}
                                </SelectContent>
                            </Select>
                        </div>
                        <div>
                            <label className="text-xs text-muted-foreground mb-1 block">Grupo muscular</label>
                            <Select value={muscleGroup} onValueChange={setMuscleGroup}>
                                <SelectTrigger><SelectValue placeholder="Selecionar" /></SelectTrigger>
                                <SelectContent>
                                    {MUSCLE_GROUPS.map(g => <SelectItem key={g} value={g}>{g}</SelectItem>)}
                                </SelectContent>
                            </Select>
                        </div>
                    </div>

                    <div>
                        <label className="text-xs text-muted-foreground mb-1 block">Link do YouTube</label>
                        <Input
                            value={videoUrl}
                            onChange={e => setVideoUrl(e.target.value)}
                            placeholder="https://youtube.com/watch?v=..."
                        />
                        {videoId && (
                            <div className="mt-2 rounded-lg overflow-hidden border border-border/40">
                                <img
                                    src={`https://img.youtube.com/vi/${videoId}/mqdefault.jpg`}
                                    alt="Preview"
                                    className="w-full h-40 object-cover"
                                />
                                <p className="text-[11px] text-muted-foreground px-2 py-1 flex items-center gap-1">
                                    <Video className="h-3 w-3" /> Vídeo detectado
                                </p>
                            </div>
                        )}
                    </div>

                    <div>
                        <label className="text-xs text-muted-foreground mb-1 block">Descrição</label>
                        <Input value={description} onChange={e => setDescription(e.target.value)} placeholder="Descrição breve..." />
                    </div>
                </div>

                <DialogFooter>
                    <Button variant="ghost" onClick={onClose}>Cancelar</Button>
                    <Button onClick={handleSave} disabled={saving || !name || !category}>
                        {saving ? "Salvando..." : "Salvar"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}

// ─────────────────────────────────────────────────────────────
// Group Panel
// ─────────────────────────────────────────────────────────────
function GroupPanel({
    groups, exercises, onGroupsChange,
}: {
    groups: ExerciseGroup[]
    exercises: Exercise[]
    onGroupsChange: (g: ExerciseGroup[]) => void
}) {
    const [expanded, setExpanded] = useState<string | null>(null)
    const [creating, setCreating] = useState(false)
    const [newGroupName, setNewGroupName] = useState("")
    const [addingTo, setAddingTo] = useState<string | null>(null)
    const [addExerciseId, setAddExerciseId] = useState("")
    const [addSets, setAddSets] = useState(3)
    const [addRepsMin, setAddRepsMin] = useState<number | null>(8)
    const [addRepsMax, setAddRepsMax] = useState<number | null>(12)
    const [addRest, setAddRest] = useState(60)

    const handleCreateGroup = async () => {
        if (!newGroupName) return
        const g = await createExerciseGroup({ name: newGroupName })
        onGroupsChange([...groups, g])
        setNewGroupName("")
        setCreating(false)
    }

    const handleDeleteGroup = async (id: string) => {
        await deleteExerciseGroup(id)
        onGroupsChange(groups.filter(g => g.id !== id))
    }

    const handleAddItem = async (groupId: string) => {
        if (!addExerciseId) return
        const item = await addExerciseGroupItem(groupId, {
            exercise_id: addExerciseId,
            sets: addSets,
            reps_min: addRepsMin,
            reps_max: addRepsMax,
            rest_seconds: addRest,
            order_index: groups.find(g => g.id === groupId)?.items.length ?? 0,
        })
        onGroupsChange(groups.map(g =>
            g.id === groupId ? { ...g, items: [...g.items, item] } : g
        ))
        setAddingTo(null)
        setAddExerciseId("")
    }

    const handleRemoveItem = async (groupId: string, itemId: string) => {
        await removeExerciseGroupItem(groupId, itemId)
        onGroupsChange(groups.map(g =>
            g.id === groupId ? { ...g, items: g.items.filter(i => i.id !== itemId) } : g
        ))
    }

    return (
        <div className="space-y-3">
            <div className="flex items-center justify-between">
                <h3 className="font-semibold text-sm text-muted-foreground uppercase tracking-wide">Grupos de exercícios</h3>
                <Button size="sm" variant="outline" onClick={() => setCreating(true)} className="h-7 text-xs gap-1">
                    <Plus className="h-3 w-3" /> Novo grupo
                </Button>
            </div>

            {creating && (
                <div className="flex gap-2">
                    <Input
                        value={newGroupName}
                        onChange={e => setNewGroupName(e.target.value)}
                        placeholder="Nome do grupo (ex: Protocolo Peito)"
                        className="h-8 text-sm"
                        onKeyDown={e => e.key === 'Enter' && handleCreateGroup()}
                    />
                    <Button size="sm" onClick={handleCreateGroup} disabled={!newGroupName} className="h-8">Criar</Button>
                    <Button size="sm" variant="ghost" onClick={() => setCreating(false)} className="h-8"><X className="h-3 w-3" /></Button>
                </div>
            )}

            {groups.length === 0 && !creating && (
                <p className="text-xs text-muted-foreground">Nenhum grupo criado ainda.</p>
            )}

            {groups.map(group => (
                <Card key={group.id} className="border-border/40">
                    <CardContent className="p-3">
                        <div className="flex items-center justify-between">
                            <button
                                onClick={() => setExpanded(expanded === group.id ? null : group.id)}
                                className="flex items-center gap-2 text-sm font-semibold hover:text-primary transition-colors"
                            >
                                <Layers className="h-4 w-4 text-primary/70" />
                                {group.name}
                                <span className="text-xs text-muted-foreground font-normal">({group.items.length} exercícios)</span>
                                {expanded === group.id ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
                            </button>
                            <Button size="icon" variant="ghost" className="h-6 w-6 text-destructive/60 hover:text-destructive"
                                onClick={() => handleDeleteGroup(group.id)}>
                                <Trash2 className="h-3 w-3" />
                            </Button>
                        </div>

                        {expanded === group.id && (
                            <div className="mt-3 space-y-2">
                                {group.items.map(item => (
                                    <div key={item.id} className="flex items-center justify-between bg-muted/30 rounded-lg px-3 py-2 text-xs">
                                        <span className="font-medium">{item.exercise?.name ?? item.exercise_id}</span>
                                        <div className="flex items-center gap-3 text-muted-foreground">
                                            <span>{item.sets}x {item.reps_min}–{item.reps_max} rep</span>
                                            <span>{item.rest_seconds}s descanso</span>
                                            <Button size="icon" variant="ghost" className="h-5 w-5 text-destructive/50 hover:text-destructive"
                                                onClick={() => handleRemoveItem(group.id, item.id)}>
                                                <X className="h-3 w-3" />
                                            </Button>
                                        </div>
                                    </div>
                                ))}

                                {addingTo === group.id ? (
                                    <div className="space-y-2 pt-1">
                                        <Select value={addExerciseId} onValueChange={setAddExerciseId}>
                                            <SelectTrigger className="h-7 text-xs"><SelectValue placeholder="Selecionar exercício" /></SelectTrigger>
                                            <SelectContent>
                                                {exercises.map(e => <SelectItem key={e.id} value={e.id}>{e.name}</SelectItem>)}
                                            </SelectContent>
                                        </Select>
                                        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                                            <div>
                                                <label className="text-[10px] text-muted-foreground">Séries</label>
                                                <Input type="number" value={addSets} onChange={e => setAddSets(+e.target.value)} className="h-7 text-xs" />
                                            </div>
                                            <div>
                                                <label className="text-[10px] text-muted-foreground">Rep min</label>
                                                <Input type="number" value={addRepsMin ?? ""} onChange={e => setAddRepsMin(+e.target.value || null)} className="h-7 text-xs" />
                                            </div>
                                            <div>
                                                <label className="text-[10px] text-muted-foreground">Rep max</label>
                                                <Input type="number" value={addRepsMax ?? ""} onChange={e => setAddRepsMax(+e.target.value || null)} className="h-7 text-xs" />
                                            </div>
                                            <div>
                                                <label className="text-[10px] text-muted-foreground">Descanso</label>
                                                <Input type="number" value={addRest} onChange={e => setAddRest(+e.target.value)} className="h-7 text-xs" />
                                            </div>
                                        </div>
                                        <div className="flex gap-1">
                                            <Button size="sm" className="h-7 text-xs" onClick={() => handleAddItem(group.id)} disabled={!addExerciseId}>Adicionar</Button>
                                            <Button size="sm" variant="ghost" className="h-7 text-xs" onClick={() => setAddingTo(null)}>Cancelar</Button>
                                        </div>
                                    </div>
                                ) : (
                                    <Button size="sm" variant="outline" className="h-7 text-xs w-full mt-1 border-dashed border-border/60"
                                        onClick={() => setAddingTo(group.id)}>
                                        <Plus className="h-3 w-3 mr-1" /> Adicionar exercício
                                    </Button>
                                )}
                            </div>
                        )}
                    </CardContent>
                </Card>
            ))}
        </div>
    )
}

// ─────────────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────────────
export default function ExercisesPage() {
    const [exercises, setExercises] = useState<Exercise[]>([])
    const [favoriteIds, setFavoriteIds] = useState<Set<string>>(new Set())
    const [groups, setGroups] = useState<ExerciseGroup[]>([])
    const [loading, setLoading] = useState(true)
    const [search, setSearch] = useState("")
    const [filterMuscle, setFilterMuscle] = useState("")
    const [filterFavorites, setFilterFavorites] = useState(false)

    const [dialogOpen, setDialogOpen] = useState(false)
    const [editTarget, setEditTarget] = useState<Exercise | null>(null)
    const [activeTab, setActiveTab] = useState<"library" | "groups">("library")

    const fetchData = useCallback(async () => {
        try {
            const [exData, favIds, grpData] = await Promise.all([
                getExercises(),
                getFavoriteExerciseIds(),
                getExerciseGroups(),
            ])
            setExercises(exData)
            setFavoriteIds(new Set(favIds))
            setGroups(grpData)
        } catch (e) {
            console.error(e)
        } finally {
            setLoading(false)
        }
    }, [])

    useEffect(() => { fetchData() }, [fetchData])

    const handleToggleFavorite = async (id: string) => {
        const result = await toggleFavoriteExercise(id)
        setFavoriteIds(prev => {
            const next = new Set(prev)
            result.is_favorite ? next.add(id) : next.delete(id)
            return next
        })
    }

    const handleSaveExercise = (ex: Exercise) => {
        setExercises(prev => {
            const idx = prev.findIndex(e => e.id === ex.id)
            return idx >= 0 ? prev.map(e => e.id === ex.id ? ex : e) : [...prev, ex]
        })
    }

    const filtered = exercises.filter(ex => {
        const matchSearch = ex.name.toLowerCase().includes(search.toLowerCase())
        const matchMuscle = !filterMuscle || filterMuscle === "all" || ex.muscle_group === filterMuscle
        const matchFav = !filterFavorites || favoriteIds.has(ex.id)
        return matchSearch && matchMuscle && matchFav
    })

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">Exercícios</h1>
                    <p className="text-sm text-muted-foreground mt-0.5">Biblioteca e grupos de exercícios</p>
                </div>
                <Button onClick={() => { setEditTarget(null); setDialogOpen(true) }} className="gap-2">
                    <Plus className="h-4 w-4" /> Novo exercício
                </Button>
            </div>

            {/* Tabs */}
            <div className="flex gap-1 border-b border-border/40">
                {(["library", "groups"] as const).map(tab => (
                    <button
                        key={tab}
                        onClick={() => setActiveTab(tab)}
                        className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${activeTab === tab
                            ? "border-primary text-primary"
                            : "border-transparent text-muted-foreground hover:text-foreground"
                            }`}
                    >
                        {tab === "library" ? "Biblioteca" : "Grupos"}
                    </button>
                ))}
            </div>

            {activeTab === "library" ? (
                <>
                    {/* Filters */}
                    <div className="flex flex-wrap gap-2">
                        <div className="relative flex-1 min-w-[200px]">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                            <Input
                                value={search}
                                onChange={e => setSearch(e.target.value)}
                                placeholder="Buscar exercício..."
                                className="pl-9 h-9"
                            />
                        </div>
                        <Select value={filterMuscle} onValueChange={setFilterMuscle}>
                            <SelectTrigger className="w-40 h-9 text-sm"><SelectValue placeholder="Grupo muscular" /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="all">Todos</SelectItem>
                                {MUSCLE_GROUPS.map(g => <SelectItem key={g} value={g}>{g}</SelectItem>)}
                            </SelectContent>
                        </Select>
                        <Button
                            variant={filterFavorites ? "default" : "outline"}
                            size="sm"
                            className="h-9 gap-1.5"
                            onClick={() => setFilterFavorites(v => !v)}
                        >
                            <Star className={`h-3.5 w-3.5 ${filterFavorites ? "fill-current" : ""}`} />
                            Favoritos
                        </Button>
                    </div>

                    {/* Exercise list */}
                    {loading ? (
                        <div className="flex justify-center py-12">
                            <div className="h-6 w-6 animate-spin rounded-full border-4 border-primary border-t-transparent" />
                        </div>
                    ) : (
                        <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
                            {filtered.map(ex => {
                                const isFav = favoriteIds.has(ex.id)
                                const videoId = ex.video_url ? youtubeIdFromUrl(ex.video_url) : null
                                return (
                                    <Card key={ex.id} className="border-border/40 hover:border-primary/30 transition-colors">
                                        <CardContent className="p-3">
                                            {videoId && (
                                                <div className="relative mb-2 rounded-md overflow-hidden">
                                                    <img
                                                        src={`https://img.youtube.com/vi/${videoId}/mqdefault.jpg`}
                                                        alt={ex.name}
                                                        className="w-full h-28 object-cover"
                                                    />
                                                    <a
                                                        href={ex.video_url!}
                                                        target="_blank"
                                                        rel="noopener noreferrer"
                                                        className="absolute inset-0 flex items-center justify-center bg-black/30 opacity-0 hover:opacity-100 transition-opacity"
                                                    >
                                                        <div className="w-10 h-10 rounded-full bg-white/90 flex items-center justify-center">
                                                            <Video className="h-5 w-5 text-black" />
                                                        </div>
                                                    </a>
                                                </div>
                                            )}
                                            <div className="flex items-start justify-between gap-2">
                                                <div className="min-w-0">
                                                    <p className="font-semibold text-sm truncate">{ex.name}</p>
                                                    <div className="flex flex-wrap gap-1 mt-1">
                                                        <span className="text-[10px] bg-primary/10 text-primary rounded px-1.5 py-0.5">{ex.category}</span>
                                                        {ex.muscle_group && (
                                                            <span className="text-[10px] bg-muted text-muted-foreground rounded px-1.5 py-0.5">{ex.muscle_group}</span>
                                                        )}
                                                    </div>
                                                </div>
                                                <div className="flex gap-1 flex-shrink-0">
                                                    <Button size="icon" variant="ghost" className={`h-7 w-7 ${isFav ? "text-yellow-500" : "text-muted-foreground"}`}
                                                        onClick={() => handleToggleFavorite(ex.id)}>
                                                        <Star className={`h-3.5 w-3.5 ${isFav ? "fill-current" : ""}`} />
                                                    </Button>
                                                    <Button size="icon" variant="ghost" className="h-7 w-7 text-muted-foreground"
                                                        onClick={() => { setEditTarget(ex); setDialogOpen(true) }}>
                                                        <Pencil className="h-3.5 w-3.5" />
                                                    </Button>
                                                </div>
                                            </div>
                                        </CardContent>
                                    </Card>
                                )
                            })}
                            {filtered.length === 0 && (
                                <div className="col-span-full text-center py-12 text-muted-foreground text-sm">
                                    Nenhum exercício encontrado.
                                </div>
                            )}
                        </div>
                    )}
                </>
            ) : (
                <GroupPanel
                    groups={groups}
                    exercises={exercises}
                    onGroupsChange={setGroups}
                />
            )}

            <ExerciseDialog
                open={dialogOpen}
                onClose={() => setDialogOpen(false)}
                initial={editTarget}
                onSave={handleSaveExercise}
            />
        </div>
    )
}
