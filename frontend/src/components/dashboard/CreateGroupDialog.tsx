"use client"

import { useEffect, useState } from "react"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

interface CreateGroupDialogProps {
    open: boolean
    onOpenChange: (open: boolean) => void
    onConfirm: (name: string, startDate?: string | null, endDate?: string | null) => void
    loading?: boolean
    /** When true, shows optional start/end date fields (program validity). */
    showDates?: boolean
    /** "edit" changes the labels/title; defaults to "create". */
    mode?: "create" | "edit"
    /** Pre-fill values when editing. */
    initial?: { name?: string; startDate?: string | null; endDate?: string | null }
}

export function CreateGroupDialog({
    open,
    onOpenChange,
    onConfirm,
    loading = false,
    showDates = false,
    mode = "create",
    initial,
}: CreateGroupDialogProps) {
    const [groupName, setGroupName] = useState("")
    const [startDate, setStartDate] = useState("")
    const [endDate, setEndDate] = useState("")

    // Sync fields whenever the dialog opens (so editing pre-fills correctly).
    useEffect(() => {
        if (open) {
            setGroupName(initial?.name ?? "")
            setStartDate(initial?.startDate ? initial.startDate.slice(0, 10) : "")
            setEndDate(initial?.endDate ? initial.endDate.slice(0, 10) : "")
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [open])

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault()
        if (groupName.trim()) {
            onConfirm(
                groupName.trim(),
                showDates ? (startDate || null) : undefined,
                showDates ? (endDate || null) : undefined,
            )
        }
    }

    const isEdit = mode === "edit"

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-zinc-900 border-zinc-800">
                <form onSubmit={handleSubmit}>
                    <DialogHeader>
                        <DialogTitle className="text-white">
                            {isEdit ? "Editar Pasta" : "Criar Pasta de Treinos"}
                        </DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            {isEdit
                                ? "Atualize o nome e a validade desta pasta."
                                : 'Organize os treinos do aluno (ex: "Mês 1", "Hipertrofia", "Cutting").'}
                        </DialogDescription>
                    </DialogHeader>
                    <div className="py-4 space-y-4">
                        <div>
                            <Label htmlFor="group-name" className="text-white">Nome da Pasta</Label>
                            <Input
                                id="group-name"
                                value={groupName}
                                onChange={(e) => setGroupName(e.target.value)}
                                placeholder="Ex: Mês 1"
                                className="mt-2 bg-zinc-900 border-zinc-800 text-white"
                                disabled={loading}
                                autoFocus
                            />
                        </div>
                        {showDates && (
                            <div className="grid grid-cols-2 gap-3">
                                <div>
                                    <Label htmlFor="start-date" className="text-white">Início</Label>
                                    <Input
                                        id="start-date"
                                        type="date"
                                        value={startDate}
                                        onChange={(e) => setStartDate(e.target.value)}
                                        className="mt-2 bg-zinc-900 border-zinc-800 text-white"
                                        disabled={loading}
                                    />
                                </div>
                                <div>
                                    <Label htmlFor="end-date" className="text-white">Término</Label>
                                    <Input
                                        id="end-date"
                                        type="date"
                                        value={endDate}
                                        onChange={(e) => setEndDate(e.target.value)}
                                        className="mt-2 bg-zinc-900 border-zinc-800 text-white"
                                        disabled={loading}
                                    />
                                </div>
                            </div>
                        )}
                    </div>
                    <DialogFooter>
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => onOpenChange(false)}
                            disabled={loading}
                            className="border-zinc-700 hover:bg-zinc-800"
                        >
                            Cancelar
                        </Button>
                        <Button type="submit" disabled={loading || !groupName.trim()}>
                            {loading ? "Salvando..." : isEdit ? "Salvar" : "Criar Pasta"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    )
}
