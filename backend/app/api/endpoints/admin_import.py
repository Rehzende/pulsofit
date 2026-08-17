from typing import Any
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.db.session import get_db
from app.models.exercise import ExerciseLibrary, MuscleGroup
from app.models.user import User, UserRole
import json

router = APIRouter()

@router.post("/import-from-json")
async def import_exercises_from_json(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Import exercises from JSON file (Admin/Trainer only)
    """
    if current_user.role not in [UserRole.SUPER_ADMIN, UserRole.TRAINER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
    
    # Read JSON file
    content = await file.read()
    exercises_data = json.loads(content.decode('utf-8'))
    
    # Get existing exercises
    result = await db.execute(select(ExerciseLibrary))
    existing_exercises = {ex.name: ex for ex in result.scalars().all()}
    
    updated_count = 0
    inserted_count = 0
    
    for ex_data in exercises_data:
        if ex_data['name'] in existing_exercises:
            # Update existing
            ex = existing_exercises[ex_data['name']]
            ex.category = ex_data['category']
            ex.muscle_group = MuscleGroup(ex_data['muscle_group'])
            ex.met_value = ex_data['met_value']
            ex.video_url = ex_data.get('video_url')
            ex.is_iot_compatible = ex_data.get('is_iot_compatible', False)
            updated_count += 1
        else:
            # Insert new
            exercise = ExerciseLibrary(
                name=ex_data['name'],
                category=ex_data['category'],
                muscle_group=MuscleGroup(ex_data['muscle_group']),
                met_value=ex_data['met_value'],
                video_url=ex_data.get('video_url'),
                is_iot_compatible=ex_data.get('is_iot_compatible', False)
            )
            db.add(exercise)
            inserted_count += 1
    
    await db.commit()
    
    return {
        "message": "Import completed successfully",
        "updated": updated_count,
        "inserted": inserted_count,
        "total": len(existing_exercises) + inserted_count
    }
