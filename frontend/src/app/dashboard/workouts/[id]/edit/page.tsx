"use client"

import { useState, useEffect } from "react"
import { useParams, useRouter } from "next/navigation"
import { Plus, Trash2, Check, ChevronsUpDown, Link, Unlink, ArrowLeft } from "lucide-react"
import { ApiClient, WorkoutItemCreate, Exercise, WorkoutGroup } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Slider } from "@/components/ui/slider"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command"
import { cn } from "@/lib/utils"

const customFilter = (value: string, search: string) => {
    if (!search) return 1;
    const normalizeString = (text: string) => {
        return text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    };

    const searchWords = normalizeString(search).split(/\s+/).filter(w => w.length > 0);
    const itemValue = normalizeString(value);
    
    // Check if ALL search words are present in the item value
    const matchesAll = searchWords.every(word => itemValue.includes(word));
    return matchesAll ? 1 : 0;
};

export default function EditWorkoutPage() {
    const params = useParams()
    const router = useRouter()
    const id = params.id as string

    const [exercises, setExercises] = useState<Exercise[]>([])
    const [groups, setGroups] = useState<WorkoutGroup[]>([])
    const [loading, setLoading] = useState(false)
    const [initialLoading, setInitialLoading] = useState(true)
    const [error, setError] = useState<string | null>(null)

    const [workoutName, setWorkoutName] = useState("")
    const [scheduledFor, setScheduledFor] = useState("")
    const [startDate, setStartDate] = useState("")
    const [endDate, setEndDate] = useState("")
    const [selectedGroupId, setSelectedGroupId] = useState<string>("none")

    const [items, setItems] = useState<WorkoutItemCreate[]>([])
    const [itemTypes, setItemTypes] = useState<("reps" | "duration")[]>([])

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [workout, exercisesData, groupsData] = await Promise.all([
                    ApiClient.getWorkout(id),
                    ApiClient.getExercises(),
                    ApiClient.getWorkoutGroups(),
                ])

                setExercises(exercisesData)
                setGroups(groupsData)

                setWorkoutName(workout.name)
                setSelectedGroupId(workout.group_id || "none")

                if (workout.scheduled_for) {
                    setScheduledFor(new Date(workout.scheduled_for).toISOString().slice(0, 16))
                }
                if (workout.start_date) {
                    setStartDate(new Date(workout.start_date).toISOString().slice(0, 16))
                }
                if (workout.end_date) {
                    setEndDate(new Date(workout.end_date).toISOString().slice(0, 16))
                }

                const mappedItems: WorkoutItemCreate[] = workout.items.map(item => ({
                    exercise_id: item.exercise_id,
                    exercise_name: item.exercise_name || "",
                    sets: item.sets,
                    reps_min: item.reps_min ?? null,
                    reps_max: item.reps_max ?? null,
                    reps_per_set: item.reps_per_set ?? null,
                    duration_seconds: null,
                    rest_seconds: item.rest_seconds,
                    notes: item.notes ?? null,
                    target_zone_min_bpm: item.target_zone_min_bpm ?? 100,
                    target_zone_max_bpm: item.target_zone_max_bpm ?? 150,
                    target_rpe: item.target_rpe ?? null,
                    superset_id: item.superset_id ?? null,
                }))

                const mappedTypes: ("reps" | "duration")[] = mappedItems.map(item =>
                    item.reps_min != null || item.reps_max != null ? "reps" : "duration"
                )

                setItems(mappedItems)
                setItemTypes(mappedTypes)
            } catch (err) {
                console.error(err)
                setError("Falha ao carregar treino.")
            } finally {
                setInitialLoading(false)
            }
        }
        fetchData()
    }, [id])

    const handleAddItem = () => {
        setItems([...items, {
            exercise_name: "",
            exercise_id: "",
            sets: 3,
            reps_min: 8,
            reps_max: 12,
            duration_seconds: null,
            rest_seconds: 60,
            target_zone_min_bpm: 100,
            target_zone_max_bpm: 150,
            target_rpe: 5,
            superset_id: null,
        }])
        setItemTypes([...itemTypes, "reps"])
    }

    const handleRemoveItem = (index: number) => {
        const newItems = [...items]
        newItems.splice(index, 1)
        setItems(newItems)
        const newTypes = [...itemTypes]
        newTypes.splice(index, 1)
        setItemTypes(newTypes)
    }

    const handleExerciseSelect = (index: number, exercise: Exercise) => {
        const newItems = [...items]
        const newTypes = [...itemTypes]
        newItems[index] = { ...newItems[index], exercise_id: exercise.id, exercise_name: exercise.name }
        if (exercise.category.toUpperCase() === "CARDIO") {
            newItems[index].target_zone_min_bpm = 120
            newItems[index].target_zone_max_bpm = 160
            newItems[index].target_rpe = null
            newTypes[index] = "duration"
            newItems[index].duration_seconds = 300
            newItems[index].reps_min = null
            newItems[index].reps_max = null
        } else {
            newItems[index].target_rpe = 7
            newTypes[index] = "reps"
            newItems[index].reps_min = 8
            newItems[index].reps_max = 12
            newItems[index].duration_seconds = null
        }
        setItems(newItems)
        setItemTypes(newTypes)
    }

    const handleItemChange = (index: number, field: keyof WorkoutItemCreate, value: any) => {
        const newItems = [...items]
        newItems[index] = { ...newItems[index], [field]: value }
        setItems(newItems)
    }

    // Keeps the per-set reps array in sync when the set count changes.
    const handleSetsChange = (index: number, sets: number) => {
        const newItems = [...items]
        const it = { ...newItems[index], sets }
        if (Array.isArray(it.reps_per_set)) {
            const arr = [...it.reps_per_set]
            const fill = arr[arr.length - 1] ?? it.reps_max ?? it.reps_min ?? 10
            if (sets > arr.length) {
                while (arr.length < sets) arr.push(fill)
            } else {
                arr.length = Math.max(0, sets)
            }
            it.reps_per_set = arr
        }
        newItems[index] = it
        setItems(newItems)
    }

    const toggleRepsPerSet = (index: number) => {
        const newItems = [...items]
        const it = { ...newItems[index] }
        if (Array.isArray(it.reps_per_set)) {
            it.reps_per_set = null
        } else {
            const base = it.reps_max ?? it.reps_min ?? 10
            it.reps_per_set = Array.from({ length: Math.max(1, it.sets || 1) }, () => base)
        }
        newItems[index] = it
        setItems(newItems)
    }

    const handleRepPerSetChange = (index: number, setIdx: number, value: number) => {
        const newItems = [...items]
        const it = { ...newItems[index] }
        const arr = Array.isArray(it.reps_per_set) ? [...it.reps_per_set] : []
        arr[setIdx] = value
        it.reps_per_set = arr
        newItems[index] = it
        setItems(newItems)
    }

    const handleLinkItem = (index: number) => {
        if (index === 0) return
        const newItems = [...items]
        const prevItem = newItems[index - 1]
        const currentItem = newItems[index]
        if (prevItem.superset_id) {
            newItems[index] = { ...currentItem, superset_id: prevItem.superset_id }
        } else {
            const newSupersetId = crypto.randomUUID()
            newItems[index - 1] = { ...prevItem, superset_id: newSupersetId }
            newItems[index] = { ...currentItem, superset_id: newSupersetId }
        }
        setItems(newItems)
    }

    const handleUnlinkItem = (index: number) => {
        const newItems = [...items]
        const oldSupersetId = newItems[index].superset_id
        newItems[index] = { ...newItems[index], superset_id: null }
        const othersInSuperset = newItems.filter((item, i) => i !== index && item.superset_id === oldSupersetId)
        if (othersInSuperset.length === 1) {
            const otherIndex = newItems.findIndex((item, i) => i !== index && item.superset_id === oldSupersetId)
            if (otherIndex !== -1) {
                newItems[otherIndex] = { ...newItems[otherIndex], superset_id: null }
            }
        }
        setItems(newItems)
    }

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setError(null)

        if (!workoutName.trim()) {
            setError("Por favor, insira um nome para o treino.")
            return
        }
        const itemsWithoutExercise = items.filter(item => !item.exercise_id)
        if (itemsWithoutExercise.length > 0) {
            setError(`Por favor, selecione um exercício para todos os itens (${itemsWithoutExercise.length} item(s) sem exercício selecionado).`)
            return
        }

        setLoading(true)
        try {
            await ApiClient.updateWorkout(id, {
                name: workoutName,
                scheduled_for: scheduledFor ? new Date(scheduledFor).toISOString() : null,
                start_date: startDate ? new Date(startDate).toISOString() : null,
                end_date: endDate ? new Date(endDate).toISOString() : null,
                group_id: selectedGroupId === "none" ? null : selectedGroupId,
                items,
            })
            router.push("/dashboard/workouts")
        } catch (err: any) {
            console.error(err)
            const detail = err.response?.data?.detail
            if (Array.isArray(detail)) {
                setError("Erro de validação: verifique se todos os campos obrigatórios estão preenchidos.")
            } else if (typeof detail === "string") {
                setError(detail)
            } else {
                setError("Falha ao salvar treino. Tente novamente.")
            }
        } finally {
            setLoading(false)
        }
    }

    if (initialLoading) {
        return <div className="p-6 text-zinc-400">Carregando...</div>
    }

    return (
        <div className="container mx-auto py-10 max-w-4xl">
            <div className="flex items-center gap-3 mb-8">
                <Button variant="ghost" size="icon" onClick={() => router.back()}>
                    <ArrowLeft className="h-4 w-4" />
                </Button>
                <h1 className="text-3xl font-bold">Editar Treino</h1>
            </div>

            {error && (
                <div className="bg-destructive/15 text-destructive p-4 rounded-md mb-6">
                    {error}
                </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-8">
                <Card className="bg-zinc-900 border-zinc-800">
                    <CardHeader>
                        <CardTitle className="text-white">Informações do Treino</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div className="space-y-2">
                            <Label htmlFor="name">Nome do Treino</Label>
                            <Input
                                id="name"
                                value={workoutName}
                                onChange={(e) => setWorkoutName(e.target.value)}
                                placeholder="Ex: Treino A - Peito e Tríceps"
                                required
                                className="bg-zinc-900 border-zinc-800 text-white"
                            />
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="group">Grupo (Opcional)</Label>
                            <select
                                id="group"
                                className="flex h-10 w-full rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2 text-sm text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                                value={selectedGroupId}
                                onChange={(e) => setSelectedGroupId(e.target.value)}
                            >
                                <option value="none">Sem Grupo</option>
                                {groups.map(g => (
                                    <option key={g.id} value={g.id}>{g.name}</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="scheduled">Agendado Para (Opcional)</Label>
                            <Input
                                id="scheduled"
                                type="datetime-local"
                                value={scheduledFor}
                                onChange={(e) => setScheduledFor(e.target.value)}
                                className="bg-zinc-900 border-zinc-800 text-white"
                            />
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="space-y-2">
                                <Label htmlFor="startDate">Data de Início (Opcional)</Label>
                                <Input
                                    id="startDate"
                                    type="datetime-local"
                                    value={startDate}
                                    onChange={(e) => setStartDate(e.target.value)}
                                    className="bg-zinc-900 border-zinc-800 text-white"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="endDate">Data de Fim (Opcional)</Label>
                                <Input
                                    id="endDate"
                                    type="datetime-local"
                                    value={endDate}
                                    onChange={(e) => setEndDate(e.target.value)}
                                    className="bg-zinc-900 border-zinc-800 text-white"
                                />
                            </div>
                        </div>
                    </CardContent>
                </Card>

                <div className="space-y-4">
                    <div className="flex justify-between items-center">
                        <h2 className="text-xl font-semibold text-white">Exercícios</h2>
                        <Button type="button" onClick={handleAddItem} variant="outline">
                            <Plus className="w-4 h-4 mr-2" /> Adicionar Exercício
                        </Button>
                    </div>

                    {items.map((item, index) => {
                        const isSupersetStart = item.superset_id && (index === 0 || items[index - 1].superset_id !== item.superset_id)
                        const isInSuperset = !!item.superset_id

                        return (
                            <div key={index} className="relative">
                                {isInSuperset && !isSupersetStart && (
                                    <div className="absolute left-8 -top-6 bottom-1/2 w-1 bg-blue-500/50 -z-10" />
                                )}
                                <Card className={cn(
                                    "bg-zinc-900 border-zinc-800 transition-all",
                                    isInSuperset && "border-l-4 border-l-blue-500"
                                )}>
                                    <CardContent className="pt-6">
                                        <div className="flex justify-between items-start mb-4">
                                            <div className="flex items-center gap-2">
                                                <h3 className="font-medium text-white">Exercício {index + 1}</h3>
                                                {isInSuperset && (
                                                    <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-0.5 rounded">Bi-set</span>
                                                )}
                                            </div>
                                            <div className="flex items-center gap-2">
                                                {index > 0 && (
                                                    <Button
                                                        type="button"
                                                        variant="ghost"
                                                        size="sm"
                                                        onClick={() => isInSuperset ? handleUnlinkItem(index) : handleLinkItem(index)}
                                                        className={cn(isInSuperset ? "text-blue-400" : "text-zinc-500 hover:text-white")}
                                                    >
                                                        {isInSuperset ? <Unlink className="w-4 h-4" /> : <Link className="w-4 h-4" />}
                                                    </Button>
                                                )}
                                                <Button type="button" variant="ghost" size="sm" onClick={() => handleRemoveItem(index)}>
                                                    <Trash2 className="w-4 h-4 text-destructive" />
                                                </Button>
                                            </div>
                                        </div>

                                        <div className="space-y-4">
                                            {/* Exercise selector - full width */}
                                            <div className="space-y-2">
                                                <Label>Exercício</Label>
                                                <Popover>
                                                    <PopoverTrigger asChild>
                                                        <Button
                                                            variant="outline"
                                                            role="combobox"
                                                            className={cn("w-full justify-between", !item.exercise_name && "text-muted-foreground")}
                                                        >
                                                            {item.exercise_name || "Selecionar exercício..."}
                                                            <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0" />
                                                        </Button>
                                                    </PopoverTrigger>
                                                    <PopoverContent className="w-[min(400px,calc(100vw-2rem))] p-0 bg-zinc-900 border-zinc-800">
                                                        <Command className="bg-zinc-900" filter={customFilter}>
                                                            <CommandInput placeholder="Buscar exercícios..." className="bg-zinc-900 border-zinc-800 text-white" />
                                                            <CommandList className="bg-zinc-900">
                                                                <CommandEmpty className="text-zinc-500 pt-2 pb-2">Nenhum exercício encontrado.</CommandEmpty>
                                                                <CommandGroup>
                                                                    {exercises.map((exercise) => (
                                                                        <CommandItem
                                                                            key={exercise.id}
                                                                            value={exercise.name}
                                                                            onSelect={() => handleExerciseSelect(index, exercise)}
                                                                            className="text-white hover:bg-zinc-800 aria-selected:bg-zinc-800"
                                                                        >
                                                                            <Check className={cn("mr-2 h-4 w-4", item.exercise_id === exercise.id ? "opacity-100" : "opacity-0")} />
                                                                            <div className="flex flex-col">
                                                                                <span>{exercise.name}</span>
                                                                                <span className="text-xs text-zinc-500">{exercise.category}</span>
                                                                            </div>
                                                                        </CommandItem>
                                                                    ))}
                                                                </CommandGroup>
                                                            </CommandList>
                                                        </Command>
                                                    </PopoverContent>
                                                </Popover>
                                            </div>

                                            {/* Séries + Descanso side by side */}
                                            <div className="grid grid-cols-2 gap-3">
                                                <div className="space-y-2">
                                                    <Label>Séries</Label>
                                                    <Input
                                                        type="number"
                                                        value={item.sets}
                                                        onChange={(e) => handleSetsChange(index, parseInt(e.target.value) || 0)}
                                                        className="bg-zinc-900 border-zinc-800 text-white"
                                                    />
                                                </div>
                                                <div className="space-y-2">
                                                    <Label>Descanso (s)</Label>
                                                    <Input
                                                        type="number"
                                                        value={item.rest_seconds}
                                                        onChange={(e) => handleItemChange(index, "rest_seconds", parseInt(e.target.value))}
                                                        className="bg-zinc-900 border-zinc-800 text-white"
                                                    />
                                                </div>
                                            </div>

                                            {/* Reps or Duration - full width row */}
                                            <div className="space-y-2">
                                                <div className="flex justify-between items-center">
                                                    <Label>{itemTypes[index] === "reps" ? "Repetições" : "Duração"}</Label>
                                                    <button
                                                        type="button"
                                                        onClick={() => {
                                                            const newTypes = [...itemTypes]
                                                            newTypes[index] = newTypes[index] === "reps" ? "duration" : "reps"
                                                            setItemTypes(newTypes)
                                                            const newItems = [...items]
                                                            if (newTypes[index] === "duration") {
                                                                newItems[index].reps_min = null
                                                                newItems[index].reps_max = null
                                                                newItems[index].reps_per_set = null
                                                                newItems[index].duration_seconds = 300
                                                            } else {
                                                                newItems[index].duration_seconds = null
                                                                newItems[index].reps_min = 8
                                                                newItems[index].reps_max = 12
                                                            }
                                                            setItems(newItems)
                                                        }}
                                                        className="text-xs text-blue-400 hover:text-blue-300"
                                                    >
                                                        Mudar para {itemTypes[index] === "reps" ? "duração" : "repetições"}
                                                    </button>
                                                </div>
                                                {itemTypes[index] === "reps" ? (
                                                    <div className="space-y-2">
                                                        <div className="inline-flex rounded-md border border-zinc-800 p-0.5 bg-zinc-900/60">
                                                            <button
                                                                type="button"
                                                                onClick={() => { if (Array.isArray(item.reps_per_set)) toggleRepsPerSet(index) }}
                                                                className={`px-3 py-1 text-xs rounded ${!Array.isArray(item.reps_per_set) ? "bg-primary text-primary-foreground" : "text-zinc-400 hover:text-white"}`}
                                                            >
                                                                Faixa
                                                            </button>
                                                            <button
                                                                type="button"
                                                                onClick={() => { if (!Array.isArray(item.reps_per_set)) toggleRepsPerSet(index) }}
                                                                className={`px-3 py-1 text-xs rounded ${Array.isArray(item.reps_per_set) ? "bg-primary text-primary-foreground" : "text-zinc-400 hover:text-white"}`}
                                                            >
                                                                Por série
                                                            </button>
                                                        </div>

                                                        {!Array.isArray(item.reps_per_set) ? (
                                                            <div className="flex gap-2">
                                                                <Input
                                                                    type="number"
                                                                    placeholder="Mín"
                                                                    value={item.reps_min || ""}
                                                                    onChange={(e) => handleItemChange(index, "reps_min", parseInt(e.target.value))}
                                                                    className="bg-zinc-900 border-zinc-800 text-white"
                                                                />
                                                                <Input
                                                                    type="number"
                                                                    placeholder="Máx"
                                                                    value={item.reps_max || ""}
                                                                    onChange={(e) => handleItemChange(index, "reps_max", parseInt(e.target.value))}
                                                                    className="bg-zinc-900 border-zinc-800 text-white"
                                                                />
                                                            </div>
                                                        ) : (
                                                            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                                                                {item.reps_per_set.map((reps, setIdx) => (
                                                                    <div key={setIdx} className="flex items-center gap-2">
                                                                        <span className="text-xs text-zinc-500 w-12 flex-shrink-0">Série {setIdx + 1}</span>
                                                                        <Input
                                                                            type="number"
                                                                            value={reps || ""}
                                                                            onChange={(e) => handleRepPerSetChange(index, setIdx, parseInt(e.target.value) || 0)}
                                                                            className="bg-zinc-900 border-zinc-800 text-white"
                                                                        />
                                                                    </div>
                                                                ))}
                                                            </div>
                                                        )}
                                                    </div>
                                                ) : (
                                                    <div className="flex gap-2 items-center">
                                                        <Input
                                                            type="number"
                                                            placeholder="Segundos"
                                                            value={item.duration_seconds || ""}
                                                            onChange={(e) => handleItemChange(index, "duration_seconds", parseInt(e.target.value))}
                                                            className="bg-zinc-900 border-zinc-800 text-white"
                                                        />
                                                        <span className="text-xs text-zinc-500 whitespace-nowrap">
                                                            {item.duration_seconds ? `${Math.floor((item.duration_seconds || 0) / 60)}:${String((item.duration_seconds || 0) % 60).padStart(2, "0")}` : "0:00"}
                                                        </span>
                                                    </div>
                                                )}
                                            </div>

                                            {/* Heart rate zone */}
                                            <div className="space-y-3 border border-zinc-800 p-4 rounded-md bg-zinc-800/30">
                                                <div className="flex justify-between">
                                                    <Label>Zona de FC (BPM)</Label>
                                                    <span className="text-sm text-zinc-500">
                                                        {item.target_zone_min_bpm} - {item.target_zone_max_bpm} BPM
                                                    </span>
                                                </div>
                                                <Slider
                                                    min={60}
                                                    max={220}
                                                    step={1}
                                                    value={[item.target_zone_min_bpm || 100, item.target_zone_max_bpm || 150]}
                                                    onValueChange={(val) => {
                                                        handleItemChange(index, "target_zone_min_bpm", val[0])
                                                        handleItemChange(index, "target_zone_max_bpm", val[1])
                                                    }}
                                                />
                                            </div>

                                            {/* Notes */}
                                            <div className="space-y-2">
                                                <Label>Observações</Label>
                                                <Input
                                                    value={item.notes || ""}
                                                    onChange={(e) => handleItemChange(index, "notes", e.target.value)}
                                                    placeholder="Instruções, carga, etc..."
                                                    className="bg-zinc-900 border-zinc-800 text-white"
                                                />
                                            </div>
                                        </div>
                                    </CardContent>
                                </Card>
                            </div>
                        )
                    })}
                </div>

                <Button type="submit" className="w-full" disabled={loading}>
                    {loading ? "Salvando..." : "Salvar Alterações"}
                </Button>
            </form>
        </div>
    )
}
