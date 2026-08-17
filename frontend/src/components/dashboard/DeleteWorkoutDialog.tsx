"use client"

import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"

interface DeleteWorkoutDialogProps {
    open: boolean
    onOpenChange: (open: boolean) => void
    workoutName: string
    onConfirm: () => void
    loading?: boolean
}

export function DeleteWorkoutDialog({
    open,
    onOpenChange,
    workoutName,
    onConfirm,
    loading = false
}: DeleteWorkoutDialogProps) {
    return (
        <AlertDialog open={open} onOpenChange={onOpenChange}>
            <AlertDialogContent className="bg-zinc-900 border-zinc-800">
                <AlertDialogHeader>
                    <AlertDialogTitle className="text-white">Deletar Treino</AlertDialogTitle>
                    <AlertDialogDescription className="text-zinc-400">
                        Tem certeza que deseja deletar o treino <strong className="text-white">"{workoutName}"</strong>?
                        Esta ação não pode ser desfeita.
                    </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel disabled={loading} className="border-zinc-700 hover:bg-zinc-800">Cancelar</AlertDialogCancel>
                    <AlertDialogAction
                        onClick={onConfirm}
                        disabled={loading}
                        className="bg-red-600 hover:bg-red-700"
                    >
                        {loading ? "Deletando..." : "Deletar"}
                    </AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>
    )
}
