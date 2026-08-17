"use client"

import { useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ApiClient, User } from "@/lib/api"
import type { Workout, WorkoutGroup } from "@/lib/api"
import {
    Activity, Calendar, Heart, TrendingUp, Plus, Dumbbell, Pencil, Play,
    MessageCircle, Folder, FolderOpen, FolderPlus, MoreVertical, Archive,
    ArchiveRestore, Trash2, FolderInput, CheckCircle2, AlertTriangle,
} from "lucide-react"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
    Accordion, AccordionContent, AccordionItem, AccordionTrigger,
} from "@/components/ui/accordion"
import {
    DropdownMenu, DropdownMenuTrigger, DropdownMenuContent,
    DropdownMenuItem, DropdownMenuSeparator, DropdownMenuLabel,
} from "@/components/ui/dropdown-menu"
import {
    AlertDialog, AlertDialogContent, AlertDialogHeader, AlertDialogTitle,
    AlertDialogDescription, AlertDialogFooter, AlertDialogCancel, AlertDialogAction,
} from "@/components/ui/alert-dialog"
import { CreateGroupDialog } from "@/components/dashboard/CreateGroupDialog"
import { DeleteWorkoutDialog } from "@/components/dashboard/DeleteWorkoutDialog"

const UNGROUPED = "ungrouped"

export default function StudentDetailPage() {
    const params = useParams()
    const router = useRouter()
    const id = params.id as string

    const [student, setStudent] = useState<User | null>(null)
    const [stats, setStats] = useState<{ attendance_rate?: number; current_streak?: number } | null>(null)
    const [workouts, setWorkouts] = useState<Workout[]>([])
    const [groups, setGroups] = useState<WorkoutGroup[]>([])
    const [isLoading, setIsLoading] = useState(true)

    // Workout edit dialog
    const [editingWorkout, setEditingWorkout] = useState<Workout | null>(null)
    const [editName, setEditName] = useState("")
    const [editDate, setEditDate] = useState("")
    const [isEditDialogOpen, setIsEditDialogOpen] = useState(false)

    // Folder dialogs
    const [groupDialogOpen, setGroupDialogOpen] = useState(false)
    const [editingGroup, setEditingGroup] = useState<WorkoutGroup | null>(null)
    const [savingGroup, setSavingGroup] = useState(false)
    const [deleteGroupTarget, setDeleteGroupTarget] = useState<WorkoutGroup | null>(null)

    // Workout delete dialog
    const [deleteWorkoutTarget, setDeleteWorkoutTarget] = useState<Workout | null>(null)
    const [deletingWorkout, setDeletingWorkout] = useState(false)

    const fetchData = async () => {
        try {
            const [studentData, statsData, workoutsData, groupsData] = await Promise.all([
                ApiClient.getStudent(id),
                ApiClient.trainer.getStats(id),
                ApiClient.getWorkouts(id),
                ApiClient.getWorkoutGroups(id).catch(() => [] as WorkoutGroup[]),
            ])
            setStudent(studentData)
            setStats(statsData as { attendance_rate?: number; current_streak?: number })
            setWorkouts(workoutsData)
            setGroups(groupsData)
        } catch (error) {
            console.error("Failed to fetch student data", error)
        } finally {
            setIsLoading(false)
        }
    }

    useEffect(() => {
        if (id) fetchData()
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [id])

    // ── Workout edit ────────────────────────────────────────────────
    const openEditDialog = (workout: Workout, e: React.MouseEvent) => {
        e.stopPropagation()
        setEditingWorkout(workout)
        setEditName(workout.name)
        const date = workout.scheduled_for ? new Date(workout.scheduled_for) : new Date()
        const localIso = new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
        setEditDate(localIso)
        setIsEditDialogOpen(true)
    }

    const handleUpdate = async () => {
        if (!editingWorkout) return
        try {
            const updated = await ApiClient.updateWorkout(editingWorkout.id, {
                name: editName,
                scheduled_for: new Date(editDate).toISOString(),
            })
            setWorkouts(workouts.map(w => w.id === updated.id ? updated : w))
            setIsEditDialogOpen(false)
            setEditingWorkout(null)
        } catch (error) {
            console.error("Failed to update workout", error)
        }
    }

    const handleActivate = async (workout: Workout, e: React.MouseEvent) => {
        e.stopPropagation()
        try {
            const updated = await ApiClient.updateWorkout(workout.id, {
                scheduled_for: new Date().toISOString(),
            })
            setWorkouts(workouts.map(w => w.id === updated.id ? updated : w))
        } catch (error) {
            console.error("Failed to activate workout", error)
        }
    }

    const handleMoveToGroup = async (workout: Workout, groupId: string | null) => {
        try {
            const updated = await ApiClient.updateWorkout(workout.id, { group_id: groupId })
            setWorkouts(workouts.map(w => w.id === updated.id ? updated : w))
        } catch (error) {
            console.error("Failed to move workout", error)
        }
    }

    const handleDeleteWorkout = async () => {
        if (!deleteWorkoutTarget) return
        setDeletingWorkout(true)
        try {
            await ApiClient.deleteWorkout(deleteWorkoutTarget.id)
            setWorkouts(workouts.filter(w => w.id !== deleteWorkoutTarget.id))
            setDeleteWorkoutTarget(null)
        } catch (error) {
            console.error("Failed to delete workout", error)
        } finally {
            setDeletingWorkout(false)
        }
    }

    // ── Folder management ───────────────────────────────────────────
    const openCreateGroup = () => {
        setEditingGroup(null)
        setGroupDialogOpen(true)
    }

    const openEditGroup = (group: WorkoutGroup) => {
        setEditingGroup(group)
        setGroupDialogOpen(true)
    }

    const handleSaveGroup = async (name: string, startDate?: string | null, endDate?: string | null) => {
        setSavingGroup(true)
        try {
            if (editingGroup) {
                const updated = await ApiClient.updateWorkoutGroup(editingGroup.id, {
                    name, start_date: startDate, end_date: endDate,
                })
                setGroups(groups.map(g => g.id === updated.id ? updated : g))
            } else {
                const created = await ApiClient.createWorkoutGroup(name, {
                    student_id: id, start_date: startDate, end_date: endDate,
                })
                setGroups([...groups, created])
            }
            setGroupDialogOpen(false)
            setEditingGroup(null)
        } catch (error) {
            console.error("Failed to save group", error)
            const detail = (error as { response?: { data?: { detail?: string } } })?.response?.data?.detail
            alert(detail || "Erro ao salvar pasta")
        } finally {
            setSavingGroup(false)
        }
    }

    const handleArchiveGroup = async (group: WorkoutGroup) => {
        try {
            const updated = group.is_active === false
                ? await ApiClient.unarchiveWorkoutGroup(group.id)
                : await ApiClient.archiveWorkoutGroup(group.id)
            setGroups(groups.map(g => g.id === updated.id ? updated : g))
        } catch (error) {
            console.error("Failed to archive group", error)
        }
    }

    const handleDeleteGroup = async () => {
        if (!deleteGroupTarget) return
        try {
            await ApiClient.deleteWorkoutGroup(deleteGroupTarget.id)
            // Workouts inside become ungrouped (backend sets group_id NULL).
            setWorkouts(workouts.map(w => w.group_id === deleteGroupTarget.id ? { ...w, group_id: null } : w))
            setGroups(groups.filter(g => g.id !== deleteGroupTarget.id))
            setDeleteGroupTarget(null)
        } catch (error) {
            console.error("Failed to delete group", error)
        }
    }

    if (isLoading) {
        return (
            <div className="grid gap-4">
                {Array.from({ length: 4 }).map((_, i) => (
                    <div key={i} className="h-24 rounded-xl bg-zinc-900/50 animate-pulse" />
                ))}
            </div>
        )
    }

    if (!student) return <div className="text-zinc-400">Aluno não encontrado</div>

    // ── Derived ─────────────────────────────────────────────────────
    const activeGroups = groups.filter(g => g.is_active !== false)
    const archivedGroups = groups.filter(g => g.is_active === false)
    const ungrouped = workouts.filter(w => !w.group_id)
    const groupWorkouts = (gid: string) => workouts.filter(w => w.group_id === gid)
    const isExpired = (g: WorkoutGroup) => !!g.end_date && new Date(g.end_date) < new Date()
    const isDone = (w: Workout) => w.sessions?.some(s => s.status === "FINISHED")

    const hasAnyContent = workouts.length > 0 || groups.length > 0

    return (
        <div className="flex flex-col gap-6">
            {/* Header */}
            <div className="flex flex-wrap justify-between items-start gap-3">
                <div className="flex flex-col gap-1">
                    <h1 className="text-2xl md:text-3xl font-bold tracking-tight">{student.full_name || student.email}</h1>
                    <p className="text-zinc-500">{student.email}</p>
                </div>
                <div className="flex gap-2 w-full md:w-auto flex-wrap">
                    <Link href={`/dashboard/students/${id}/sessions`} className="flex-1 md:flex-none min-w-fit">
                        <Button variant="outline" className="w-full"><Activity className="mr-2 h-4 w-4" /> Histórico</Button>
                    </Link>
                    <Link href={`/dashboard/chat?student_id=${id}`} className="flex-1 md:flex-none min-w-fit">
                        <Button variant="outline" className="w-full"><MessageCircle className="mr-2 h-4 w-4" /> Chat</Button>
                    </Link>
                    <Button variant="outline" className="flex-1 md:flex-none min-w-fit" onClick={openCreateGroup}>
                        <FolderPlus className="mr-2 h-4 w-4" /> Nova Pasta
                    </Button>
                    <Link href={`/dashboard/workouts/new?student_id=${id}`} className="flex-1 md:flex-none min-w-fit">
                        <Button className="w-full"><Plus className="mr-2 h-4 w-4" /> Novo Treino</Button>
                    </Link>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
                {[
                    { label: "Frequência", value: `${stats?.attendance_rate || 0}%`, sub: "Últimos 30 dias", icon: Calendar },
                    { label: "Sequência", value: stats?.current_streak || 0, sub: "Semanas", icon: TrendingUp },
                    { label: "FC Repouso", value: student.resting_hr || "--", sub: "BPM", icon: Heart },
                    { label: "FC Máxima", value: student.max_hr || "--", sub: "BPM", icon: Activity },
                ].map((s) => (
                    <Card key={s.label} className="bg-zinc-900 border-zinc-800">
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium text-white">{s.label}</CardTitle>
                            <s.icon className="h-4 w-4 text-zinc-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-2xl font-bold text-white">{s.value}</div>
                            <p className="text-xs text-zinc-500">{s.sub}</p>
                        </CardContent>
                    </Card>
                ))}
            </div>

            {/* Workouts & Folders */}
            <Card className="bg-zinc-900 border-zinc-800">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-white">
                        <Dumbbell className="h-5 w-5" /> Treinos
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    {!hasAnyContent ? (
                        <EmptyState onNewFolder={openCreateGroup} studentId={id} />
                    ) : (
                        <Accordion
                            type="multiple"
                            defaultValue={[...activeGroups.map(g => g.id), UNGROUPED]}
                            className="w-full"
                        >
                            {/* Active groups */}
                            {activeGroups.map(group => {
                                const gw = groupWorkouts(group.id)
                                const expired = isExpired(group)
                                return (
                                    <AccordionItem key={group.id} value={group.id} className="border-zinc-800">
                                        <div className="flex items-center gap-1 pr-1">
                                            <AccordionTrigger className="hover:no-underline hover:bg-zinc-800/40 px-3 rounded-lg flex-1 min-w-0">
                                                <div className="flex items-center gap-2 min-w-0">
                                                    <FolderOpen className={`h-5 w-5 flex-shrink-0 ${expired ? "text-amber-500" : "text-primary"}`} />
                                                    <span className="font-semibold text-white truncate">{group.name}</span>
                                                    <span className="text-xs text-zinc-500 flex-shrink-0">({gw.length})</span>
                                                    {expired && (
                                                        <Badge variant="outline" className="border-amber-500/40 text-amber-500 text-[10px] flex-shrink-0">
                                                            <AlertTriangle className="h-3 w-3 mr-1" /> Vencida
                                                        </Badge>
                                                    )}
                                                </div>
                                            </AccordionTrigger>
                                            <FolderMenu
                                                onEdit={() => openEditGroup(group)}
                                                onArchive={() => handleArchiveGroup(group)}
                                                onDelete={() => setDeleteGroupTarget(group)}
                                            />
                                        </div>
                                        <AccordionContent>
                                            {group.end_date && (
                                                <p className="px-3 pb-2 text-xs text-zinc-500">
                                                    Programa até {new Date(group.end_date).toLocaleDateString("pt-BR")}
                                                </p>
                                            )}
                                            <div className="space-y-2 px-1">
                                                {gw.length === 0 ? (
                                                    <p className="text-sm text-zinc-500 px-3 py-2">Pasta vazia. Adicione o primeiro treino.</p>
                                                ) : (
                                                    gw.map(w => (
                                                        <WorkoutRow
                                                            key={w.id} workout={w} done={!!isDone(w)}
                                                            groups={activeGroups} currentGroupId={group.id}
                                                            onOpen={() => router.push(`/dashboard/workouts/${w.id}`)}
                                                            onEdit={(e) => openEditDialog(w, e)}
                                                            onActivate={(e) => handleActivate(w, e)}
                                                            onMove={(gid) => handleMoveToGroup(w, gid)}
                                                            onDelete={() => setDeleteWorkoutTarget(w)}
                                                        />
                                                    ))
                                                )}
                                                <Link href={`/dashboard/workouts/new?student_id=${id}&group_id=${group.id}`} className="block">
                                                    <Button variant="outline" size="sm" className="w-full border-dashed border-primary/40 text-primary hover:bg-primary/10">
                                                        <Plus className="mr-2 h-4 w-4" /> Adicionar treino nesta pasta
                                                    </Button>
                                                </Link>
                                            </div>
                                        </AccordionContent>
                                    </AccordionItem>
                                )
                            })}

                            {/* Ungrouped */}
                            <AccordionItem value={UNGROUPED} className="border-zinc-800">
                                <AccordionTrigger className="hover:no-underline hover:bg-zinc-800/40 px-3 rounded-lg">
                                    <div className="flex items-center gap-2 min-w-0">
                                        <Folder className="h-5 w-5 text-zinc-400 flex-shrink-0" />
                                        <span className="font-semibold text-white truncate">Sem Pasta</span>
                                        <span className="text-xs text-zinc-500 flex-shrink-0">({ungrouped.length})</span>
                                    </div>
                                </AccordionTrigger>
                                <AccordionContent>
                                    <div className="space-y-2 px-1">
                                        {ungrouped.length === 0 ? (
                                            <p className="text-sm text-zinc-500 px-3 py-2">Nenhum treino solto.</p>
                                        ) : (
                                            ungrouped.map(w => (
                                                <WorkoutRow
                                                    key={w.id} workout={w} done={!!isDone(w)}
                                                    groups={activeGroups} currentGroupId={null}
                                                    onOpen={() => router.push(`/dashboard/workouts/${w.id}`)}
                                                    onEdit={(e) => openEditDialog(w, e)}
                                                    onActivate={(e) => handleActivate(w, e)}
                                                    onMove={(gid) => handleMoveToGroup(w, gid)}
                                                    onDelete={() => setDeleteWorkoutTarget(w)}
                                                />
                                            ))
                                        )}
                                        <Link href={`/dashboard/workouts/new?student_id=${id}`} className="block">
                                            <Button variant="outline" size="sm" className="w-full border-dashed border-primary/40 text-primary hover:bg-primary/10">
                                                <Plus className="mr-2 h-4 w-4" /> Novo treino sem pasta
                                            </Button>
                                        </Link>
                                    </div>
                                </AccordionContent>
                            </AccordionItem>

                            {/* Archived */}
                            {archivedGroups.length > 0 && (
                                <AccordionItem value="archived" className="border-zinc-800">
                                    <AccordionTrigger className="hover:no-underline hover:bg-zinc-800/40 px-3 rounded-lg">
                                        <div className="flex items-center gap-2">
                                            <Archive className="h-5 w-5 text-zinc-500" />
                                            <span className="font-semibold text-zinc-400">Pastas Arquivadas</span>
                                            <span className="text-xs text-zinc-500">({archivedGroups.length})</span>
                                        </div>
                                    </AccordionTrigger>
                                    <AccordionContent>
                                        <div className="space-y-2 px-1">
                                            {archivedGroups.map(group => (
                                                <div key={group.id} className="flex items-center justify-between p-3 border border-zinc-800 rounded-lg">
                                                    <div className="flex flex-col min-w-0">
                                                        <span className="font-medium text-zinc-300 truncate">{group.name}</span>
                                                        <span className="text-xs text-zinc-500">{groupWorkouts(group.id).length} treino(s)</span>
                                                    </div>
                                                    <Button variant="ghost" size="sm" className="text-primary" onClick={() => handleArchiveGroup(group)}>
                                                        <ArchiveRestore className="h-4 w-4 mr-1" /> Restaurar
                                                    </Button>
                                                </div>
                                            ))}
                                        </div>
                                    </AccordionContent>
                                </AccordionItem>
                            )}
                        </Accordion>
                    )}
                </CardContent>
            </Card>

            {/* Anamnesis */}
            <Card className="bg-zinc-900 border-zinc-800">
                <CardHeader><CardTitle className="text-white">Histórico Médico (Anamnese)</CardTitle></CardHeader>
                <CardContent>
                    {student.medical_history && Object.keys(student.medical_history).length > 0 ? (
                        <div className="grid gap-4 md:grid-cols-2">
                            {Object.entries(student.medical_history).map(([key, value]) => (
                                <div key={key} className="flex flex-col gap-1">
                                    <span className="text-sm font-medium capitalize text-white">{key.replace(/_/g, " ")}</span>
                                    <span className="text-sm text-zinc-500">
                                        {typeof value === "boolean" ? (value ? "Sim" : "Não") : String(value)}
                                    </span>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <p className="text-zinc-500">Nenhum histórico médico disponível.</p>
                    )}
                </CardContent>
            </Card>

            {/* ── Dialogs ─────────────────────────────────────────────── */}
            <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800">
                    <DialogHeader><DialogTitle className="text-white">Editar Treino</DialogTitle></DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label htmlFor="name" className="text-white">Nome do Treino</Label>
                            <Input id="name" value={editName} onChange={(e) => setEditName(e.target.value)} className="bg-zinc-900 border-zinc-800 text-white" />
                        </div>
                        <div className="grid gap-2">
                            <Label htmlFor="date" className="text-white">Data Agendada</Label>
                            <Input id="date" type="datetime-local" value={editDate} onChange={(e) => setEditDate(e.target.value)} className="bg-zinc-900 border-zinc-800 text-white" />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setIsEditDialogOpen(false)} className="border-zinc-700 hover:bg-zinc-800">Cancelar</Button>
                        <Button onClick={handleUpdate}>Salvar</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            <CreateGroupDialog
                open={groupDialogOpen}
                onOpenChange={(o) => { setGroupDialogOpen(o); if (!o) setEditingGroup(null) }}
                onConfirm={handleSaveGroup}
                loading={savingGroup}
                showDates
                mode={editingGroup ? "edit" : "create"}
                initial={editingGroup ? { name: editingGroup.name, startDate: editingGroup.start_date, endDate: editingGroup.end_date } : undefined}
            />

            <DeleteWorkoutDialog
                open={!!deleteWorkoutTarget}
                onOpenChange={(o) => { if (!o) setDeleteWorkoutTarget(null) }}
                workoutName={deleteWorkoutTarget?.name || ""}
                onConfirm={handleDeleteWorkout}
                loading={deletingWorkout}
            />

            <AlertDialog open={!!deleteGroupTarget} onOpenChange={(o) => { if (!o) setDeleteGroupTarget(null) }}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800">
                    <AlertDialogHeader>
                        <AlertDialogTitle className="text-white">Excluir pasta?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            A pasta &quot;{deleteGroupTarget?.name}&quot; será removida. Os treinos dentro dela <strong>não</strong> serão deletados — voltam para &quot;Sem Pasta&quot;.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="border-zinc-700 hover:bg-zinc-800">Cancelar</AlertDialogCancel>
                        <AlertDialogAction onClick={handleDeleteGroup} className="bg-red-600 hover:bg-red-700">Excluir</AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </div>
    )
}

// ── Sub-components ──────────────────────────────────────────────────

function FolderMenu({ onEdit, onArchive, onDelete }: { onEdit: () => void; onArchive: () => void; onDelete: () => void }) {
    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className="h-8 w-8 flex-shrink-0 text-zinc-400 hover:text-white">
                    <MoreVertical className="h-4 w-4" />
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="bg-zinc-900 border-zinc-800 text-white">
                <DropdownMenuItem onClick={onEdit} className="cursor-pointer focus:bg-zinc-800">
                    <Pencil className="h-4 w-4 mr-2" /> Editar pasta
                </DropdownMenuItem>
                <DropdownMenuItem onClick={onArchive} className="cursor-pointer focus:bg-zinc-800 text-amber-500">
                    <Archive className="h-4 w-4 mr-2" /> Arquivar
                </DropdownMenuItem>
                <DropdownMenuSeparator className="bg-zinc-800" />
                <DropdownMenuItem onClick={onDelete} className="cursor-pointer focus:bg-zinc-800 text-red-500">
                    <Trash2 className="h-4 w-4 mr-2" /> Excluir
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>
    )
}

interface WorkoutRowProps {
    workout: Workout
    done: boolean
    groups: WorkoutGroup[]
    currentGroupId: string | null
    onOpen: () => void
    onEdit: (e: React.MouseEvent) => void
    onActivate: (e: React.MouseEvent) => void
    onMove: (groupId: string | null) => void
    onDelete: () => void
}

function WorkoutRow({ workout, done, groups, currentGroupId, onOpen, onEdit, onActivate, onMove, onDelete }: WorkoutRowProps) {
    const isPast = !!workout.scheduled_for && new Date(workout.scheduled_for) < new Date()
    const dateLabel = workout.scheduled_for
        ? new Date(workout.scheduled_for).toLocaleDateString("pt-BR")
        : "Sem data"
    const exerciseCount = workout.items?.length ?? 0

    return (
        <div
            className="group flex items-center justify-between p-3 border border-zinc-800 rounded-lg hover:bg-zinc-800/50 cursor-pointer"
            onClick={onOpen}
        >
            <div className="flex items-center gap-3 min-w-0">
                <div className="h-9 w-9 rounded-lg bg-primary/15 flex items-center justify-center flex-shrink-0">
                    <Dumbbell className="h-4 w-4 text-primary" />
                </div>
                <div className="flex flex-col min-w-0">
                    <span className={`font-medium truncate ${done ? "text-zinc-400" : "text-white"}`}>{workout.name}</span>
                    <span className="text-xs text-zinc-500">{dateLabel} · {exerciseCount} ex.</span>
                </div>
            </div>
            <div className="flex items-center gap-2 flex-shrink-0">
                {done ? (
                    <Badge variant="secondary" className="hidden sm:inline-flex"><CheckCircle2 className="h-3 w-3 mr-1" /> Concluído</Badge>
                ) : (
                    <Badge variant={isPast ? "destructive" : "default"} className="hidden sm:inline-flex">{isPast ? "Pendente" : "Agendado"}</Badge>
                )}
                <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity" onClick={(e) => e.stopPropagation()}>
                    <Button variant="ghost" size="icon" className="h-8 w-8" onClick={onEdit} title="Editar"><Pencil className="h-4 w-4" /></Button>
                    {isPast && !done && (
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-green-500" onClick={onActivate} title="Ativar (mover para hoje)"><Play className="h-4 w-4" /></Button>
                    )}
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon" className="h-8 w-8" title="Mover para pasta"><FolderInput className="h-4 w-4" /></Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="bg-zinc-900 border-zinc-800 text-white">
                            <DropdownMenuLabel className="text-zinc-400">Mover para…</DropdownMenuLabel>
                            <DropdownMenuItem disabled={currentGroupId === null} onClick={() => onMove(null)} className="cursor-pointer focus:bg-zinc-800">
                                <Folder className="h-4 w-4 mr-2" /> Sem Pasta
                            </DropdownMenuItem>
                            {groups.map(g => (
                                <DropdownMenuItem key={g.id} disabled={currentGroupId === g.id} onClick={() => onMove(g.id)} className="cursor-pointer focus:bg-zinc-800">
                                    <FolderOpen className="h-4 w-4 mr-2" /> {g.name}
                                </DropdownMenuItem>
                            ))}
                        </DropdownMenuContent>
                    </DropdownMenu>
                    <Button variant="ghost" size="icon" className="h-8 w-8 text-red-500" onClick={onDelete} title="Excluir"><Trash2 className="h-4 w-4" /></Button>
                </div>
            </div>
        </div>
    )
}

function EmptyState({ onNewFolder, studentId }: { onNewFolder: () => void; studentId: string }) {
    return (
        <div className="flex flex-col items-center text-center py-10 gap-4">
            <div className="h-16 w-16 rounded-full bg-primary/10 flex items-center justify-center">
                <Dumbbell className="h-8 w-8 text-primary" />
            </div>
            <div>
                <p className="text-lg font-semibold text-white">Comece o plano deste aluno</p>
                <p className="text-sm text-zinc-500 mt-1">Crie uma pasta (ex: &quot;Mês 1&quot;) para organizar, ou já adicione um treino.</p>
            </div>
            <div className="flex gap-2">
                <Button variant="outline" onClick={onNewFolder}><FolderPlus className="mr-2 h-4 w-4" /> Nova pasta</Button>
                <Link href={`/dashboard/workouts/new?student_id=${studentId}`}>
                    <Button><Plus className="mr-2 h-4 w-4" /> Novo treino</Button>
                </Link>
            </div>
        </div>
    )
}
