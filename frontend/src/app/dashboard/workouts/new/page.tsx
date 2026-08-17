"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Plus, Trash2, Check, ChevronsUpDown, Link, Unlink, Layers, ChevronUp, ChevronDown } from "lucide-react"
import { ApiClient, User, WorkoutItemCreate, Exercise, WorkoutGroup, ExerciseGroup, getExerciseGroups } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Slider } from "@/components/ui/slider"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
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

export default function CreateWorkoutPage() {
    const router = useRouter()
    const [students, setStudents] = useState<User[]>([])
    const [exercises, setExercises] = useState<Exercise[]>([])
    const [groups, setGroups] = useState<WorkoutGroup[]>([])
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState<string | null>(null)

    const [workoutName, setWorkoutName] = useState("")
    const [selectedStudentId, setSelectedStudentId] = useState("")
    const [scheduledFor, setScheduledFor] = useState("")
    const [startDate, setStartDate] = useState("")
    const [endDate, setEndDate] = useState("")
    const [selectedGroupId, setSelectedGroupId] = useState<string>("none")
    const [isCreateExerciseOpen, setIsCreateExerciseOpen] = useState(false)
    const [addingExerciseToIndex, setAddingExerciseToIndex] = useState<number | null>(null)
    const [exerciseGroups, setExerciseGroups] = useState<ExerciseGroup[]>([])
    const [isInsertGroupOpen, setIsInsertGroupOpen] = useState(false)

    const [items, setItems] = useState<WorkoutItemCreate[]>([
        {
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
        }
    ])
    const [itemTypes, setItemTypes] = useState<("reps" | "duration")[]>(["reps"])

    useEffect(() => {
        const fetchData = async () => {
            try {
                // Check for token first
                const token = localStorage.getItem("token")
                if (!token) {
                    setError("No auth token found. Please login first.")
                    return
                }

                // Fetch students and exercises independently to avoid total failure
                let studentsData: User[] = []
                let exercisesData: Exercise[] = []
                let groupsData: WorkoutGroup[] = []

                try {
                    studentsData = await ApiClient.getStudents()
                    setStudents(studentsData)
                } catch (err) {
                    console.error("Failed to load students:", err)
                    // Don't set error - allow exercises to still load
                }

                try {
                    exercisesData = await ApiClient.getExercises()
                    setExercises(exercisesData)
                } catch (err) {
                    console.error("Failed to load exercises:", err)
                    setError("Failed to load exercises. Please try again.")
                    return
                }

                try {
                    groupsData = await ApiClient.getWorkoutGroups()
                    setGroups(groupsData)
                } catch (err) {
                    console.error("Failed to load groups:", err)
                }

                try {
                    const exGroups = await getExerciseGroups()
                    setExerciseGroups(exGroups)
                } catch (err) {
                    console.error("Failed to load exercise groups:", err)
                }

                // Check if student_id is in URL query params
                const urlParams = new URLSearchParams(window.location.search)
                const studentIdFromUrl = urlParams.get('student_id')
                const groupIdFromUrl = urlParams.get('group_id')

                if (studentIdFromUrl && studentsData.some(s => s.id === studentIdFromUrl)) {
                    setSelectedStudentId(studentIdFromUrl)
                } else if (studentsData.length > 0) {
                    setSelectedStudentId(studentsData[0].id)
                }

                if (groupIdFromUrl) {
                    setSelectedGroupId(groupIdFromUrl)
                }
            } catch (err) {
                console.error(err)
                setError("Failed to load data. Make sure backend is running and you are logged in.")
            }
        }
        fetchData()
    }, [])

    const handleInsertGroup = (group: ExerciseGroup) => {
        const newItems = group.items
            .sort((a, b) => a.order_index - b.order_index)
            .map(item => ({
                exercise_name: item.exercise?.name ?? "",
                exercise_id: item.exercise_id,
                sets: item.sets,
                reps_min: item.reps_min ?? 8,
                reps_max: item.reps_max ?? 12,
                duration_seconds: item.duration_seconds ?? null,
                rest_seconds: item.rest_seconds,
                target_zone_min_bpm: 100,
                target_zone_max_bpm: 150,
                target_rpe: 5,
                superset_id: null,
            }))
        setItems(prev => [...prev, ...newItems])
        setItemTypes(prev => [...prev, ...newItems.map(() => "reps" as const)])
        setIsInsertGroupOpen(false)
    }

    const handleAddItem = () => {
        setItems([
            ...items,
            {
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
            }
        ])
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

    const handleMoveItem = (index: number, direction: 'up' | 'down') => {
        const target = direction === 'up' ? index - 1 : index + 1
        if (target < 0 || target >= items.length) return

        const newItems = [...items]
        ;[newItems[index], newItems[target]] = [newItems[target], newItems[index]]
        setItems(newItems)

        const newTypes = [...itemTypes]
        ;[newTypes[index], newTypes[target]] = [newTypes[target], newTypes[index]]
        setItemTypes(newTypes)
    }

    const handleExerciseSelect = (index: number, exercise: Exercise) => {
        const newItems = [...items]
        const newTypes = [...itemTypes]
        newItems[index] = {
            ...newItems[index],
            exercise_id: exercise.id,
            exercise_name: exercise.name,
        }

        // Auto-configure based on category
        // If category is CARDIO, prioritize heart rate monitoring and duration
        if (exercise.category.toUpperCase() === 'CARDIO') {
            // Set reasonable default heart rate zones for cardio
            newItems[index].target_zone_min_bpm = 120
            newItems[index].target_zone_max_bpm = 160
            // Clear RPE for cardio (heart rate is primary)
            newItems[index].target_rpe = null
            // Default to duration for cardio
            newTypes[index] = "duration"
            newItems[index].duration_seconds = 300 // 5 minutes default
            newItems[index].reps_min = null
            newItems[index].reps_max = null
            newItems[index].reps_per_set = null
        } else {
            // For strength exercises, prioritize RPE and reps
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

    // Changing the number of sets keeps the per-set reps array in sync.
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

    // Toggle between a single range (reps_min–reps_max) and per-set reps.
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

        // If previous item is already in a superset, join it
        if (prevItem.superset_id) {
            newItems[index] = { ...currentItem, superset_id: prevItem.superset_id }
        } else {
            // Create a new superset for both
            const newSupersetId = crypto.randomUUID()
            newItems[index - 1] = { ...prevItem, superset_id: newSupersetId }
            newItems[index] = { ...currentItem, superset_id: newSupersetId }
        }
        setItems(newItems)
    }

    const handleUnlinkItem = (index: number) => {
        const newItems = [...items]
        const currentItem = newItems[index]

        // If unlinking, we just remove the superset_id from this item
        // Note: If this leaves only one item in the superset, we might want to clean that up, 
        // but strictly speaking it's not invalid, just a superset of 1. 
        // For cleaner data, let's check neighbors.

        const oldSupersetId = currentItem.superset_id
        newItems[index] = { ...currentItem, superset_id: null }

        // Check if any other items share this superset_id
        const othersInSuperset = newItems.filter((item, i) => i !== index && item.superset_id === oldSupersetId)
        if (othersInSuperset.length === 1) {
            // If only one left, remove its superset_id too
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
        if (!selectedStudentId) {
            setError("Por favor, selecione um aluno.")
            return
        }
        const itemsWithoutExercise = items.filter(item => !item.exercise_id)
        if (itemsWithoutExercise.length > 0) {
            setError(`Por favor, selecione um exercício para todos os itens (${itemsWithoutExercise.length} item(s) sem exercício selecionado).`)
            return
        }

        setLoading(true)

        try {
            // Convert datetime-local format to ISO string
            const scheduledForISO = scheduledFor
                ? new Date(scheduledFor).toISOString()
                : null

            await ApiClient.createWorkout({
                name: workoutName,
                student_id: selectedStudentId,
                scheduled_for: scheduledForISO,
                start_date: startDate ? new Date(startDate).toISOString() : null,
                end_date: endDate ? new Date(endDate).toISOString() : null,
                group_id: selectedGroupId === "none" ? null : selectedGroupId,
                items: items
            })
            router.push('/dashboard/workouts')
        } catch (err: any) {
            console.error(err)
            const detail = err.response?.data?.detail
            if (Array.isArray(detail)) {
                setError("Erro de validação: verifique se todos os campos obrigatórios estão preenchidos.")
            } else if (typeof detail === "string") {
                setError(detail)
            } else {
                setError("Falha ao criar treino. Tente novamente.")
            }
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="container mx-auto py-6 max-w-4xl">
            <h1 className="text-2xl sm:text-3xl font-bold mb-6">Criar Treino</h1>

            {error && (
                <div className="bg-destructive/15 text-destructive p-4 rounded-md mb-6">
                    {error}
                </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-8">
                <Card className="bg-zinc-900 border-zinc-800">
                    <CardHeader>
                        <CardTitle className="text-white">Detalhes do Treino</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
                                <Label htmlFor="student">Aluno</Label>
                                <Select value={selectedStudentId} onValueChange={setSelectedStudentId}>
                                    <SelectTrigger id="student" className="bg-zinc-900 border-zinc-800 text-white">
                                        <SelectValue placeholder="Selecione um aluno" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {students.map(s => (
                                            <SelectItem key={s.id} value={s.id}>{s.full_name || s.email}</SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="group">Grupo (Opcional)</Label>
                            <Select value={selectedGroupId} onValueChange={setSelectedGroupId}>
                                <SelectTrigger id="group" className="bg-zinc-900 border-zinc-800 text-white">
                                    <SelectValue placeholder="Selecione um grupo" />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">Sem grupo</SelectItem>
                                    {groups.map(g => (
                                        <SelectItem key={g.id} value={g.id}>{g.name}</SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                            <div className="space-y-2">
                                <Label htmlFor="scheduled">Data Agendada</Label>
                                <Input
                                    id="scheduled"
                                    type="datetime-local"
                                    value={scheduledFor}
                                    onChange={(e) => setScheduledFor(e.target.value)}
                                    className="bg-zinc-900 border-zinc-800 text-white"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="startDate">Data de Início</Label>
                                <Input
                                    id="startDate"
                                    type="datetime-local"
                                    value={startDate}
                                    onChange={(e) => setStartDate(e.target.value)}
                                    className="bg-zinc-900 border-zinc-800 text-white"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="endDate">Data de Fim</Label>
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
                        <div className="flex gap-2">
                            {exerciseGroups.length > 0 && (
                                <Button type="button" onClick={() => setIsInsertGroupOpen(true)} variant="outline" className="gap-2">
                                    <Layers className="w-4 h-4" /> Inserir grupo
                                </Button>
                            )}
                            <Button type="button" onClick={handleAddItem} variant="outline">
                                <Plus className="w-4 h-4 mr-2" /> Adicionar Exercício
                            </Button>
                        </div>
                    </div>

                    {items.map((item, index) => {
                        const isSupersetStart = item.superset_id && (index === 0 || items[index - 1].superset_id !== item.superset_id)
                        const isSupersetEnd = item.superset_id && (index === items.length - 1 || items[index + 1].superset_id !== item.superset_id)
                        const isInSuperset = !!item.superset_id

                        return (
                            <div key={index} className="relative">
                                {/* Visual connector for superset */}
                                {isInSuperset && !isSupersetStart && (
                                    <div className="absolute left-8 -top-6 bottom-1/2 w-1 bg-blue-500/50 -z-10" />
                                )}

                                <Card className={cn(
                                    "bg-zinc-900 border-zinc-800 transition-all",
                                    isInSuperset && "border-l-4 border-l-blue-500"
                                )}>
                                    <CardContent className="pt-6">
                                        <div className="flex justify-between items-start mb-4">
                                            <div className="flex items-center gap-2 flex-wrap">
                                                <h3 className="font-medium text-white">Exercício {index + 1}</h3>
                                                {isInSuperset && (
                                                    <span className="text-xs bg-blue-500/20 text-blue-400 border border-blue-500/30 px-2 py-0.5 rounded-full font-semibold">
                                                        🔗 Bi-set
                                                    </span>
                                                )}
                                            </div>
                                            <div className="flex items-center gap-1">
                                                <Button
                                                    type="button"
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-7 w-7 p-0 text-zinc-400 hover:text-white"
                                                    disabled={index === 0}
                                                    onClick={() => handleMoveItem(index, 'up')}
                                                >
                                                    <ChevronUp className="w-4 h-4" />
                                                </Button>
                                                <Button
                                                    type="button"
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-7 w-7 p-0 text-zinc-400 hover:text-white"
                                                    disabled={index === items.length - 1}
                                                    onClick={() => handleMoveItem(index, 'down')}
                                                >
                                                    <ChevronDown className="w-4 h-4" />
                                                </Button>
                                                {index > 0 && (
                                                    <Button
                                                        type="button"
                                                        variant={isInSuperset ? "secondary" : "outline"}
                                                        size="sm"
                                                        onClick={() => isInSuperset ? handleUnlinkItem(index) : handleLinkItem(index)}
                                                        className={cn(
                                                            "text-xs h-7 px-2",
                                                            isInSuperset
                                                                ? "bg-blue-500/20 text-blue-400 border-blue-500/30 hover:bg-blue-500/30"
                                                                : "border-zinc-700 text-zinc-400 hover:text-white hover:border-zinc-500"
                                                        )}
                                                    >
                                                        {isInSuperset
                                                            ? <><Unlink className="w-3 h-3 mr-1" /> Desfazer bi-set</>
                                                            : <><Link className="w-3 h-3 mr-1" /> Bi-set com anterior</>
                                                        }
                                                    </Button>
                                                )}
                                                <Button type="button" variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => handleRemoveItem(index)}>
                                                    <Trash2 className="w-4 h-4 text-destructive" />
                                                </Button>
                                            </div>
                                        </div>

                                        <div className="space-y-4">
                                            {/* Exercise selector - full width */}
                                            <div className="space-y-2">
                                                <Label className={!item.exercise_id ? "text-destructive" : ""}>
                                                    Exercício *
                                                </Label>
                                                <Popover>
                                                    <PopoverTrigger asChild>
                                                        <Button
                                                            variant="outline"
                                                            role="combobox"
                                                            className={cn(
                                                                "w-full justify-between",
                                                                !item.exercise_name && "text-muted-foreground",
                                                                !item.exercise_id && "border-destructive/50"
                                                            )}
                                                        >
                                                            {item.exercise_name || "Selecionar exercício..."}
                                                            <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0" />
                                                        </Button>
                                                    </PopoverTrigger>
                                                    <PopoverContent className="w-[min(400px,calc(100vw-2rem))] p-0 bg-zinc-900 border-zinc-800">
                                                        <Command className="bg-zinc-900" filter={customFilter}>
                                                            <CommandInput placeholder="Buscar exercício..." className="bg-zinc-900 border-zinc-800 text-white" />
                                                            <CommandList className="bg-zinc-900">
                                                                <CommandEmpty className="text-zinc-500 pt-2 pb-2">
                                                                    <p className="mb-2">Nenhum exercício encontrado.</p>
                                                                    <Button
                                                                        variant="secondary"
                                                                        size="sm"
                                                                        className="w-full"
                                                                        onClick={() => {
                                                                            setAddingExerciseToIndex(index)
                                                                            setIsCreateExerciseOpen(true)
                                                                        }}
                                                                    >
                                                                        <Plus className="w-3 h-3 mr-1" /> Criar Exercício
                                                                    </Button>
                                                                </CommandEmpty>
                                                                <CommandGroup>
                                                                    {exercises.map((exercise) => (
                                                                        <CommandItem
                                                                            key={exercise.id}
                                                                            value={exercise.name}
                                                                            onSelect={() => handleExerciseSelect(index, exercise)}
                                                                            className="text-white hover:bg-zinc-800 aria-selected:bg-zinc-800"
                                                                        >
                                                                            <Check
                                                                                className={cn(
                                                                                    "mr-2 h-4 w-4",
                                                                                    item.exercise_id === exercise.id
                                                                                        ? "opacity-100"
                                                                                        : "opacity-0"
                                                                                )}
                                                                            />
                                                                            <div className="flex flex-col">
                                                                                <span>{exercise.name}</span>
                                                                                <span className="text-xs text-zinc-500">
                                                                                    {exercise.category}
                                                                                </span>
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
                                                        onChange={(e) => handleItemChange(index, "rest_seconds", parseInt(e.target.value) || 0)}
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
                                                        {/* Faixa vs. por série */}
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
                                                                    onChange={(e) => handleItemChange(index, "reps_min", parseInt(e.target.value) || 0)}
                                                                    className="bg-zinc-900 border-zinc-800 text-white"
                                                                />
                                                                <Input
                                                                    type="number"
                                                                    placeholder="Máx"
                                                                    value={item.reps_max || ""}
                                                                    onChange={(e) => handleItemChange(index, "reps_max", parseInt(e.target.value) || 0)}
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
                                                            onChange={(e) => handleItemChange(index, "duration_seconds", parseInt(e.target.value) || 0)}
                                                            className="bg-zinc-900 border-zinc-800 text-white"
                                                        />
                                                        <span className="text-xs text-zinc-500 whitespace-nowrap">
                                                            {item.duration_seconds ? `${Math.floor((item.duration_seconds || 0) / 60)}:${String((item.duration_seconds || 0) % 60).padStart(2, '0')}` : "0:00"}
                                                        </span>
                                                    </div>
                                                )}
                                            </div>

                                            {/* Heart rate zone */}
                                            <div className="space-y-3 border border-zinc-800 p-4 rounded-md bg-zinc-800/30">
                                                <div className="flex justify-between">
                                                    <Label>Zona de Frequência Cardíaca (BPM)</Label>
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
                                                    placeholder="Instruções de execução, carga, etc."
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
                    {loading ? "Salvando..." : "Criar Treino"}
                </Button>
            </form >

            <CreateExerciseDialog
                open={isCreateExerciseOpen}
                onOpenChange={setIsCreateExerciseOpen}
                onSuccess={(newExercise) => {
                    setExercises([...exercises, newExercise])
                    // If we were adding an item, select this new exercise
                    if (addingExerciseToIndex !== null) {
                        handleExerciseSelect(addingExerciseToIndex, newExercise)
                        setAddingExerciseToIndex(null)
                    }
                }}
            />

            {/* Insert Group Dialog */}
            <Dialog open={isInsertGroupOpen} onOpenChange={setIsInsertGroupOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-md">
                    <DialogHeader>
                        <DialogTitle>Inserir grupo de exercícios</DialogTitle>
                    </DialogHeader>
                    <div className="space-y-2 max-h-80 overflow-y-auto">
                        {exerciseGroups.map(group => (
                            <button
                                key={group.id}
                                type="button"
                                onClick={() => handleInsertGroup(group)}
                                className="w-full text-left p-3 rounded-lg border border-zinc-700 hover:border-primary hover:bg-primary/10 transition-colors"
                            >
                                <div className="font-semibold text-sm">{group.name}</div>
                                <div className="text-xs text-zinc-400 mt-0.5">
                                    {group.items.length} exercício{group.items.length !== 1 ? 's' : ''}: {group.items.map(i => i.exercise?.name).filter(Boolean).join(', ')}
                                </div>
                            </button>
                        ))}
                    </div>
                </DialogContent>
            </Dialog>
        </div >
    )
}

function CreateExerciseDialog({ open, onOpenChange, onSuccess }: { open: boolean, onOpenChange: (open: boolean) => void, onSuccess: (exercise: Exercise) => void }) {
    const [name, setName] = useState("")
    const [category, setCategory] = useState("Strength")
    const [muscleGroup, setMuscleGroup] = useState("CHEST")
    const [loading, setLoading] = useState(false)
    const [error, setError] = useState<string | null>(null)

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setError(null)
        setLoading(true)
        try {
            const newExercise = await ApiClient.createExercise({
                name,
                category,
                muscle_group: muscleGroup,
                is_iot_compatible: false
            })
            onSuccess(newExercise)
            onOpenChange(false)
            setName("")
            setCategory("Strength")
        } catch (err) {
            console.error(err)
            setError("Falha ao criar exercício. Tente novamente.")
        } finally {
            setLoading(false)
        }
    }

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                <DialogHeader>
                    <DialogTitle>Criar Exercício Personalizado</DialogTitle>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4">
                    {error && (
                        <div className="bg-destructive/15 text-destructive p-3 rounded-md text-sm">
                            {error}
                        </div>
                    )}
                    <div className="space-y-2">
                        <Label htmlFor="ex-name">Nome</Label>
                        <Input
                            id="ex-name"
                            value={name}
                            onChange={e => setName(e.target.value)}
                            required
                            className="bg-zinc-800 border-zinc-700 text-white"
                        />
                    </div>
                    <div className="space-y-2">
                        <Label htmlFor="ex-category">Categoria</Label>
                        <Select value={category} onValueChange={setCategory}>
                            <SelectTrigger id="ex-category" className="bg-zinc-800 border-zinc-700 text-white">
                                <SelectValue placeholder="Selecione uma categoria" />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="Strength">Força</SelectItem>
                                <SelectItem value="Cardio">Cardio</SelectItem>
                                <SelectItem value="Flexibility">Flexibilidade</SelectItem>
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="space-y-2">
                        <Label htmlFor="ex-muscle">Grupo Muscular</Label>
                        <Select value={muscleGroup} onValueChange={setMuscleGroup}>
                            <SelectTrigger id="ex-muscle" className="bg-zinc-800 border-zinc-700 text-white">
                                <SelectValue placeholder="Selecione um grupo muscular" />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="CHEST">Peito</SelectItem>
                                <SelectItem value="BACK">Costas</SelectItem>
                                <SelectItem value="LEGS">Pernas</SelectItem>
                                <SelectItem value="ARMS">Braços</SelectItem>
                                <SelectItem value="SHOULDERS">Ombros</SelectItem>
                                <SelectItem value="CORE">Core</SelectItem>
                                <SelectItem value="CARDIO">Cardio</SelectItem>
                            </SelectContent>
                        </Select>
                    </div>
                    <Button type="submit" className="w-full" disabled={loading}>
                        {loading ? "Criando..." : "Criar Exercício"}
                    </Button>
                </form>
            </DialogContent>
        </Dialog>
    )
}
