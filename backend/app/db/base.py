# Import all the models, so that Base has them before being
# imported by Alembic
from app.db.session import Base  # noqa
from app.models import User, TrainerProfile, ExerciseLibrary, Workout, WorkoutItem, WorkoutSession, BodyAssessment, SubscriptionPlan, WorkoutGroup # noqa
from app.models.invite import StudentInvite  # noqa
from app.models.hiring_request import HiringRequest  # noqa
from app.models.magic_link import MagicLink  # noqa
