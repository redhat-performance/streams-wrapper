import pydantic
class Streams_Results(pydantic.BaseModel):
    Array_sizes: str
    Copy: int = pydantic.Field(gt=0)
    Scale: int = pydantic.Field(gt=0)
    Add: int = pydantic.Field(gt=0)
    Triad: int = pydantic.Field(gt=0)
