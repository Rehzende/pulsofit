"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { ApiClient, Workout, WorkoutGroup, User, toggleFavoriteWorkout } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
    Plus,
    Activity,
    Dumbbell,
    Calendar,
    MessageCircle,
    Search,
    Trash2,
    Folder,
    FolderOpen,
    Pencil,
    Star,
} from "lucide-react"
import {
    Accordion,
    AccordionContent,
    AccordionItem,
    AccordionTrigger,
} from "@/components/ui/accordion"
import { DeleteWorkoutDialog } from "@/components/dashboard/DeleteWorkoutDialog"
import { CreateGroupDialog } from "@/components/dashboard/CreateGroupDialog"

export default function WorkoutsPage() {
    const [workouts, setWorkouts] = useState<Workout[]>([])
    const [groups, setGroups] = useState<WorkoutGroup[]>([])
    const [user, setUser] = useState<User | null>(null)
    const [loading, setLoading] = useState(true)
    const [searchQuery, setSearchQuery] = useState("")

    // Dialog states
    const [deleteDialog, setDeleteDialog] = useState<{ open: boolean; workout: Workout | null }>({
        open: false,
        workout: null
    })
    const [createGroupDialog, setCreateGroupDialog] = useState(false)
    const [deletingWorkout, setDeletingWorkout] = useState(false)
    const [creatingGroup, setCreatingGroup] = useState(false)

    useEffect(() => {
        fetchData()
    }, [])

    const fetchData = async () => {
        try {
            // Fetch user first
            const userData = await ApiClient.getMe()
            setUser(userData)

            // Then fetch workouts and groups
            const workoutsData = await ApiClient.getWorkouts()
            setWorkouts(workoutsData)

            // Only fetch groups if user is a trainer
            if (userData.role === 'TRAINER') {
                const groupsData = await ApiClient.getWorkoutGroups()
                setGroups(groupsData)
            }
        } catch (err) {
            console.error(err)
        } finally {
            setLoading(false)
        }
    }

    const handleDeleteWorkout = async () => {
        if (!deleteDialog.workout) return

        setDeletingWorkout(true)
        try {
            await ApiClient.deleteWorkout(deleteDialog.workout.id)
            setWorkouts(workouts.filter(w => w.id !== deleteDialog.workout!.id))
            setDeleteDialog({ open: false, workout: null })
        } catch (err) {
            console.error(err)
            alert("Erro ao deletar treino")
        } finally {
            setDeletingWorkout(false)
        }
    }

    const handleCreateGroup = async (name: string) => {
        setCreatingGroup(true)
        try {
            const newGroup = await ApiClient.createWorkoutGroup(name)
            setGroups([...groups, newGroup])
            setCreateGroupDialog(false)
        } catch (err) {
            console.error(err)
            alert("Erro ao criar grupo")
        } finally {
            setCreatingGroup(false)
        }
    }

    // Filter workouts by search query
    const filteredWorkouts = workouts.filter(w =>
        w.name.toLowerCase().includes(searchQuery.toLowerCase())
    )

    // Group workouts
    const workoutsByGroup = filteredWorkouts.reduce((acc, workout) => {
        const groupId = workout.group_id || 'ungrouped'
        if (!acc[groupId]) {
            acc[groupId] = []
        }
        acc[groupId].push(workout)
        return acc
    }, {} as Record<string, Workout[]>)

    const handleToggleFavorite = async (workout: Workout) => {
        try {
            const updated = await toggleFavoriteWorkout(workout.id)
            setWorkouts(prev => prev.map(w => w.id === updated.id ? { ...w, is_favorite: updated.is_favorite } : w))
        } catch (err) {
            console.error(err)
        }
    }

    const WorkoutCard = ({ workout }: { workout: Workout }) => {
        const hasIoT = workout.items?.some(i => i.target_zone_min_bpm || i.target_zone_max_bpm)
        const isOwner = user && workout.user_id === user.id

        return (
            <Card className="card-glow hover:border-primary/50 transition-colors overflow-hidden">
                <CardContent className="flex items-center justify-between gap-2 p-3 sm:p-4">
                    <div className="flex items-start gap-2 sm:gap-3 flex-1 min-w-0">
                        <div className="h-10 w-10 rounded-xl bg-primary/15 flex items-center justify-center flex-shrink-0">
                            <Dumbbell className="h-5 w-5 text-primary" />
                        </div>
                        <div className="flex-1 min-w-0">
                            <h3 className="font-semibold text-base truncate text-foreground">{workout.name}</h3>
                            <p className="text-sm text-muted-foreground flex items-center gap-1 mt-0.5">
                                <Calendar className="h-3 w-3" />
                                {workout.start_date && workout.end_date ? (
                                    <>
                                        {new Date(workout.start_date).toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' })}
                                        {' - '}
                                        {new Date(workout.end_date).toLocaleDateString('pt-BR', { day: 'numeric', month: 'short' })}
                                    </>
                                ) : workout.scheduled_for ? (
                                    new Date(workout.scheduled_for).toLocaleDateString('pt-BR', {
                                        day: 'numeric',
                                        month: 'short'
                                    })
                                ) : "Não agendado"}
                            </p>
                        </div>
                    </div>
                    <div className="flex items-center gap-1 sm:gap-2 flex-shrink-0">
                        {hasIoT && (
                            <span className="hidden sm:inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-semibold border-border bg-secondary text-secondary-foreground">
                                <Activity className="w-3 h-3 mr-1" /> IoT
                            </span>
                        )}
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleToggleFavorite(workout)}
                            className={`flex-shrink-0 ${workout.is_favorite ? "text-yellow-400 hover:text-yellow-300" : "text-zinc-500 hover:text-yellow-400"}`}
                        >
                            <Star className={`h-4 w-4 ${workout.is_favorite ? "fill-current" : ""}`} />
                        </Button>
                        {user?.role === 'STUDENT' ? (
                            <div className="flex items-center gap-0.5 sm:gap-1 flex-shrink-0">
                                <Link href={`/dashboard/workouts/${workout.id}/run`}>
                                    <Button size="sm" className="bg-primary hover:bg-primary/90 text-primary-foreground shadow-sm shadow-primary/20 text-xs whitespace-nowrap">
                                        <Dumbbell className="h-3 w-3 sm:mr-1" />
                                        <span className="hidden sm:inline">Iniciar</span>
                                    </Button>
                                </Link>
                                {isOwner && (
                                    <>
                                        <Link href={`/dashboard/workouts/${workout.id}/edit`}>
                                            <Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground hover:bg-secondary flex-shrink-0">
                                                <Pencil className="h-4 w-4" />
                                            </Button>
                                        </Link>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            onClick={() => setDeleteDialog({ open: true, workout })}
                                            className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 flex-shrink-0"
                                        >
                                            <Trash2 className="h-4 w-4" />
                                        </Button>
                                    </>
                                )}
                            </div>
                        ) : (
                            <div className="flex items-center gap-0.5 sm:gap-1 flex-shrink-0">
                                <Link href={`/dashboard/workouts/${workout.id}`}>
                                    <Button variant="outline" size="sm" className="border-border hover:bg-secondary text-xs">Ver</Button>
                                </Link>
                                <Link href={`/dashboard/workouts/${workout.id}/edit`}>
                                    <Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground hover:bg-secondary flex-shrink-0">
                                        <Pencil className="h-4 w-4" />
                                    </Button>
                                </Link>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={() => setDeleteDialog({ open: true, workout })}
                                    className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 flex-shrink-0"
                                >
                                    <Trash2 className="h-4 w-4" />
                                </Button>
                            </div>
                        )}
                    </div>
                </CardContent>
            </Card>
        )
    }

    return (
        <div className="flex flex-col gap-4 sm:gap-6 w-full overflow-hidden">
            {/* Header */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 sm:gap-4">
                <h1 className="text-xl sm:text-2xl md:text-3xl font-bold truncate">Meus Treinos</h1>
                <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto min-w-0">
                    {user?.role === 'TRAINER' && (
                        <>
                            <Button variant="outline" className="w-full sm:w-auto" onClick={() => setCreateGroupDialog(true)}>
                                <Folder className="mr-2 h-4 w-4" /> Novo Grupo
                            </Button>
                            <Link href="/dashboard/workouts/new" className="w-full sm:w-auto">
                                <Button className="w-full sm:w-auto">
                                    <Plus className="mr-2 h-4 w-4" /> Novo Treino
                                </Button>
                            </Link>
                        </>
                    )}
                    {user?.role === 'STUDENT' && (
                        <Button variant="outline" className="w-full sm:w-auto">
                            <MessageCircle className="mr-2 h-4 w-4" /> Solicitar Novo Treino
                        </Button>
                    )}
                </div>
            </div>

            {/* Search Bar */}
            <div className="relative w-full max-w-md min-w-0">
                <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground flex-shrink-0" />
                <Input
                    type="search"
                    placeholder="Buscar treinos..."
                    className="pl-8 bg-zinc-900 border-zinc-800 text-white placeholder:text-zinc-500 focus:border-primary/50 focus:ring-primary/20"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                />
            </div>

            {/* Workouts Display */}
            {loading ? (
                <div className="grid gap-4">
                    {Array.from({ length: 3 }).map((_, i) => (
                        <div key={i} className="h-20 rounded-xl bg-zinc-900/50 animate-pulse" />
                    ))}
                </div>
            ) : filteredWorkouts.length === 0 ? (
                <Card className="p-12 text-center bg-zinc-900 border-zinc-800">
                    <Dumbbell className="h-16 w-16 mx-auto text-zinc-600 mb-4" />
                    <p className="text-zinc-400 text-lg">Nenhum treino encontrado.</p>
                    {user?.role === 'STUDENT' && (
                        <p className="text-sm text-zinc-500 mt-2">
                            Solicite um novo treino ao seu treinador!
                        </p>
                    )}
                </Card>
            ) : user?.role === 'STUDENT' ? (
                /* Student View - Simple List */
                <div className="space-y-4">
                    {/* Active Workouts */}
                    {filteredWorkouts.filter(w => !w.scheduled_for || new Date(w.scheduled_for) >= new Date()).length > 0 && (
                        <div>
                            <h2 className="text-xl font-semibold mb-3 flex items-center gap-2">
                                <Activity className="h-5 w-5 text-primary" />
                                Próximos Treinos
                            </h2>
                            <div className="grid gap-3">
                                {filteredWorkouts
                                    .filter(w => !w.scheduled_for || new Date(w.scheduled_for) >= new Date())
                                    .map(workout => <WorkoutCard key={workout.id} workout={workout} />)}
                            </div>
                        </div>
                    )}

                    {/* Past Workouts */}
                    {filteredWorkouts.filter(w => w.scheduled_for && new Date(w.scheduled_for) < new Date()).length > 0 && (
                        <div>
                            <h2 className="text-xl font-semibold mb-3 flex items-center gap-2 text-zinc-500">
                                <Calendar className="h-5 w-5" />
                                Histórico
                            </h2>
                            <div className="grid gap-3">
                                {filteredWorkouts
                                    .filter(w => w.scheduled_for && new Date(w.scheduled_for) < new Date())
                                    .map(workout => <WorkoutCard key={workout.id} workout={workout} />)}
                            </div>
                        </div>
                    )}
                </div>
            ) : (
                /* Trainer View - Groups */
                <Accordion type="multiple" defaultValue={Object.keys(workoutsByGroup)} className="w-full overflow-hidden">
                    {/* Grouped Workouts */}
                    {groups.map(group => {
                        const groupWorkouts = workoutsByGroup[group.id] || []
                        if (groupWorkouts.length === 0) return null

                        return (
                            <AccordionItem key={group.id} value={group.id} className="border-zinc-800 overflow-hidden">
                                <AccordionTrigger className="hover:no-underline hover:bg-zinc-900/50 px-3 sm:px-4 rounded-lg min-w-0">
                                    <div className="flex items-center gap-2 min-w-0">
                                        <FolderOpen className="h-5 w-5 text-primary flex-shrink-0" />
                                        <span className="font-semibold text-white truncate">{group.name}</span>
                                        <span className="text-xs sm:text-sm text-zinc-500 flex-shrink-0">
                                            ({groupWorkouts.length})
                                        </span>
                                    </div>
                                </AccordionTrigger>
                                <AccordionContent className="overflow-hidden">
                                    <div className="flex justify-end mb-2 pt-2 px-2 sm:px-4">
                                        <Link href={`/dashboard/workouts/new?group_id=${group.id}`} className="flex-shrink-0">
                                            <Button size="sm" variant="outline" className="text-xs h-8 whitespace-nowrap">
                                                <Plus className="mr-2 h-3 w-3" /> Adicionar
                                            </Button>
                                        </Link>
                                    </div>
                                    <div className="grid gap-3 px-2 sm:px-4">
                                        {groupWorkouts.map(workout => (
                                            <WorkoutCard key={workout.id} workout={workout} />
                                        ))}
                                    </div>
                                </AccordionContent>
                            </AccordionItem>
                        )
                    })}

                    {/* Ungrouped Workouts */}
                    {workoutsByGroup['ungrouped'] && workoutsByGroup['ungrouped'].length > 0 && (
                        <AccordionItem value="ungrouped" className="border-zinc-800 overflow-hidden">
                            <AccordionTrigger className="hover:no-underline hover:bg-zinc-900/50 px-3 sm:px-4 rounded-lg min-w-0">
                                <div className="flex items-center gap-2 min-w-0">
                                    <Folder className="h-5 w-5 text-gray-400 flex-shrink-0" />
                                    <span className="font-semibold text-white truncate">Sem Grupo</span>
                                    <span className="text-xs sm:text-sm text-zinc-500 flex-shrink-0">
                                        ({workoutsByGroup['ungrouped'].length})
                                    </span>
                                </div>
                            </AccordionTrigger>
                            <AccordionContent className="overflow-hidden">
                                <div className="grid gap-3 pt-2 px-2 sm:px-4">
                                    {workoutsByGroup['ungrouped'].map(workout => (
                                        <WorkoutCard key={workout.id} workout={workout} />
                                    ))}
                                </div>
                            </AccordionContent>
                        </AccordionItem>
                    )}
                </Accordion>
            )}

            {/* Dialogs */}
            <DeleteWorkoutDialog
                open={deleteDialog.open}
                onOpenChange={(open) => setDeleteDialog({ open, workout: null })}
                workoutName={deleteDialog.workout?.name || ""}
                onConfirm={handleDeleteWorkout}
                loading={deletingWorkout}
            />

            <CreateGroupDialog
                open={createGroupDialog}
                onOpenChange={setCreateGroupDialog}
                onConfirm={handleCreateGroup}
                loading={creatingGroup}
            />
        </div>
    )
}
